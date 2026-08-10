import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:mocktail/mocktail.dart' hide any;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchrofit/core/network/connectivity_monitor.dart';
import 'package:synchrofit/data/caching/caching_profile_repository.dart';
import 'package:synchrofit/data/local/daos/cache_metadata_dao.dart';
import 'package:synchrofit/data/local/daos/profile_dao.dart';
import 'package:synchrofit/data/local/daos/sync_queue_dao.dart';
import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/shared/models/models.dart';
import 'package:uuid/uuid.dart';

// Feature: offline-support-and-ui-enhancements, Property 2: Offline mutations are reflected in local cache immediately
// Feature: offline-support-and-ui-enhancements, Property 5: Successful sync removes mutation from queue
// Feature: offline-support-and-ui-enhancements, Property 1: Sync queue preserves chronological order

class MockConnectivityMonitor extends Mock implements ConnectivityMonitor {}

class MockProfileRepository extends Mock implements ProfileRepository {}

/// **Validates: Requirements 3.4**
///
/// Property 2: Offline mutations are reflected in local cache immediately
///
/// For any write operation performed while offline, reading the same entity
/// from the local cache immediately after the mutation SHALL return the
/// mutated value.
///
/// **Validates: Requirements 3.3**
///
/// Property 1: Sync queue preserves chronological order
///
/// For any sequence of mutations with distinct timestamps, getPending()
/// returns them sorted by createdAt ascending.
void main() {
  // Initialize sqflite FFI for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database database;
  late ProfileDao profileDao;
  late SyncQueueDao syncQueueDao;
  late CacheMetadataDao cacheMetadataDao;
  late MockConnectivityMonitor mockConnectivity;
  late MockProfileRepository mockRemote;
  late CachingProfileRepository cachingRepo;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE user_profile (
              user_id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              age INTEGER NOT NULL,
              height_cm REAL NOT NULL,
              weight_kg REAL NOT NULL,
              gender TEXT NOT NULL,
              fitness_goal TEXT NOT NULL,
              fitness_level TEXT NOT NULL,
              workout_preference TEXT NOT NULL,
              availability_days TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation_type TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              retry_count INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'pending'
            )
          ''');
          await db.execute('''
            CREATE TABLE cache_metadata (
              entity_type TEXT PRIMARY KEY,
              last_synced_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    profileDao = ProfileDao(database);
    syncQueueDao = SyncQueueDao(database);
    cacheMetadataDao = CacheMetadataDao(database);
    mockConnectivity = MockConnectivityMonitor();
    mockRemote = MockProfileRepository();

    // Always offline
    when(() => mockConnectivity.currentStatus)
        .thenReturn(ConnectivityStatus.offline);

    cachingRepo = CachingProfileRepository(
      remote: mockRemote,
      dao: profileDao,
      cacheMetadataDao: cacheMetadataDao,
      syncQueueDao: syncQueueDao,
      connectivity: mockConnectivity,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group(
      'Property 2: Offline mutations are reflected in local cache immediately',
      () {
    Glados3(
      any.intInRange(13, 121),
      any.doubleInRange(50.0, 300.0),
      any.doubleInRange(20.0, 500.0),
    ).test(
      'saveProfile while offline is immediately readable from cache',
      (age, heightCm, weightKg) async {
        final profile = UserProfile(
          userId: 'test-user-1',
          name: 'TestUser',
          age: age,
          heightCm: heightCm,
          weightKg: weightKg,
          gender: Gender.male,
          fitnessGoal: FitnessGoal.buildMuscle,
          fitnessLevel: FitnessLevel.intermediate,
          workoutPreference: WorkoutPreference.gym,
          workoutAvailability: [DayOfWeek.monday, DayOfWeek.wednesday],
        );

        // Perform offline save
        final result = await cachingRepo.saveProfile(profile);

        // Verify save returns success
        expect(result, isA<Success<UserProfile, AppError>>());

        // Read back from the DAO (local cache)
        final cached = await profileDao.get();

        // The written profile must be readable from cache
        expect(cached, isNotNull);
        expect(cached!.userId, equals(profile.userId));
        expect(cached.name, equals(profile.name));
        expect(cached.age, equals(profile.age));
        expect(cached.heightCm, equals(profile.heightCm));
        expect(cached.weightKg, equals(profile.weightKg));
        expect(cached.gender, equals(profile.gender));
        expect(cached.fitnessGoal, equals(profile.fitnessGoal));
        expect(cached.fitnessLevel, equals(profile.fitnessLevel));
        expect(cached.workoutPreference, equals(profile.workoutPreference));
        expect(cached.workoutAvailability, equals(profile.workoutAvailability));
        // updatedAt is set by the repo so it should be non-null
        expect(cached.updatedAt, isNotNull);
      },
    );

    Glados2(
      any.intInRange(13, 121),
      any.intInRange(0, 7),
    ).test(
      'updateProfile while offline is immediately readable from cache',
      (age, availabilityCount) async {
        // All available days to pick from
        const allDays = DayOfWeek.values;
        final selectedDays =
            allDays.take(availabilityCount.clamp(1, 7)).toList();

        // First seed initial profile in cache
        final initial = UserProfile(
          userId: 'test-user-2',
          name: 'InitialName',
          age: 25,
          heightCm: 175.0,
          weightKg: 70.0,
          gender: Gender.female,
          fitnessGoal: FitnessGoal.loseWeight,
          fitnessLevel: FitnessLevel.beginner,
          workoutPreference: WorkoutPreference.home,
          workoutAvailability: [DayOfWeek.monday],
          updatedAt: DateTime(2024, 1, 1),
        );
        await profileDao.upsert(initial);

        // Now update with new values while offline
        final updated = UserProfile(
          userId: 'test-user-2',
          name: 'UpdatedName',
          age: age,
          heightCm: 180.0,
          weightKg: 75.0,
          gender: Gender.female,
          fitnessGoal: FitnessGoal.improveEndurance,
          fitnessLevel: FitnessLevel.advanced,
          workoutPreference: WorkoutPreference.outdoor,
          workoutAvailability: selectedDays,
        );

        // Perform offline update
        final result = await cachingRepo.updateProfile(updated);
        expect(result, isA<Success<UserProfile, AppError>>());

        // Read back from cache
        final cached = await profileDao.get();
        expect(cached, isNotNull);
        expect(cached!.userId, equals(updated.userId));
        expect(cached.name, equals(updated.name));
        expect(cached.age, equals(updated.age));
        expect(cached.heightCm, equals(updated.heightCm));
        expect(cached.weightKg, equals(updated.weightKg));
        expect(cached.fitnessGoal, equals(updated.fitnessGoal));
        expect(cached.fitnessLevel, equals(updated.fitnessLevel));
        expect(cached.workoutPreference, equals(updated.workoutPreference));
        expect(cached.workoutAvailability, equals(selectedDays));
        expect(cached.updatedAt, isNotNull);
      },
    );

    Glados(any.letterOrDigits).test(
      'saveProfile while offline: getProfile returns the saved value',
      (name) async {
        final profileName = name.isEmpty ? 'DefaultName' : name;
        final profile = UserProfile(
          userId: 'test-user-3',
          name: profileName,
          age: 30,
          heightCm: 170.0,
          weightKg: 65.0,
          gender: Gender.other,
          fitnessGoal: FitnessGoal.maintainFitness,
          fitnessLevel: FitnessLevel.intermediate,
          workoutPreference: WorkoutPreference.home,
          workoutAvailability: [DayOfWeek.friday, DayOfWeek.saturday],
        );

        // Save while offline
        await cachingRepo.saveProfile(profile);

        // Read back through the caching repository's getProfile
        final readResult = await cachingRepo.getProfile('test-user-3');

        expect(readResult, isA<Success<UserProfile, AppError>>());
        final readProfile =
            (readResult as Success<UserProfile, AppError>).value;
        expect(readProfile.name, equals(profileName));
        expect(readProfile.userId, equals('test-user-3'));
        expect(readProfile.heightCm, equals(170.0));
        expect(readProfile.weightKg, equals(65.0));
        expect(readProfile.workoutAvailability,
            equals([DayOfWeek.friday, DayOfWeek.saturday]));
      },
    );
  });

  // Feature: offline-support-and-ui-enhancements, Property 1: Sync queue preserves chronological order
  group('Property 1: Sync queue preserves chronological order', () {
    /// Helper to create a fresh in-memory database for each Glados iteration
    Future<(Database, SyncQueueDao)> createSyncDb() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE sync_queue (
                id TEXT PRIMARY KEY,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                operation_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at TEXT NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0,
                status TEXT NOT NULL DEFAULT 'pending'
              )
            ''');
          },
        ),
      );
      return (db, SyncQueueDao(db));
    }

    /// **Validates: Requirements 3.3**
    ///
    /// For any sequence of mutations with distinct timestamps,
    /// getPending() returns them sorted by createdAt ascending.
    Glados(any.intInRange(2, 20)).test(
      'getPending returns mutations sorted by createdAt ascending regardless of insertion order',
      (count) async {
        final (syncDb, syncDao) = await createSyncDb();
        try {
          final baseTime = DateTime(2024, 1, 1, 12, 0, 0);

          // Generate mutations with distinct sequential timestamps
          final mutations = List.generate(count, (i) {
            return SyncMutation(
              id: 'mutation-$i',
              entityType: 'workout',
              entityId: 'entity-$i',
              operationType: 'update',
              payload: {'field': 'value-$i'},
              createdAt: baseTime.add(Duration(seconds: i)),
            );
          });

          // Shuffle to simulate non-chronological insertion order
          final shuffled = List<SyncMutation>.from(mutations)..shuffle();

          // Enqueue in shuffled order
          for (final mutation in shuffled) {
            await syncDao.enqueue(mutation);
          }

          // Retrieve pending mutations
          final pending = await syncDao.getPending();

          // Verify all mutations were enqueued
          expect(pending.length, equals(count));

          // Verify chronological order (sorted by createdAt ascending)
          for (int i = 1; i < pending.length; i++) {
            expect(
              pending[i].createdAt.isAfter(pending[i - 1].createdAt) ||
                  pending[i]
                      .createdAt
                      .isAtSameMomentAs(pending[i - 1].createdAt),
              isTrue,
              reason:
                  'Mutation at index $i (${pending[i].createdAt}) should be >= mutation at index ${i - 1} (${pending[i - 1].createdAt})',
            );
          }

          // Verify the order matches the original chronological order
          for (int i = 0; i < pending.length; i++) {
            expect(pending[i].id, equals('mutation-$i'));
          }
        } finally {
          await syncDb.close();
        }
      },
    );

    Glados(any.intInRange(2, 15)).test(
      'getPending preserves chronological order across different entity types',
      (count) async {
        final (syncDb, syncDao) = await createSyncDb();
        try {
          final baseTime = DateTime(2024, 6, 15, 8, 0, 0);
          final entityTypes = ['exercise', 'workout', 'profile', 'progress'];
          final operationTypes = ['create', 'update', 'delete'];

          // Generate mutations with distinct timestamps and varying entity types
          final mutations = List.generate(count, (i) {
            return SyncMutation(
              id: 'mixed-mutation-$i',
              entityType: entityTypes[i % entityTypes.length],
              entityId: 'entity-$i',
              operationType: operationTypes[i % operationTypes.length],
              payload: {'data': 'value-$i'},
              createdAt: baseTime.add(Duration(minutes: i)),
            );
          });

          // Shuffle and enqueue
          final shuffled = List<SyncMutation>.from(mutations)..shuffle();
          for (final mutation in shuffled) {
            await syncDao.enqueue(mutation);
          }

          // Retrieve pending
          final pending = await syncDao.getPending();

          expect(pending.length, equals(count));

          // Verify strictly ascending chronological order
          for (int i = 1; i < pending.length; i++) {
            expect(
              pending[i].createdAt.isAfter(pending[i - 1].createdAt),
              isTrue,
              reason:
                  'Mutation at index $i should have a later createdAt than index ${i - 1}',
            );
          }
        } finally {
          await syncDb.close();
        }
      },
    );
  });

  // Feature: offline-support-and-ui-enhancements, Property 3: Sync queue round-trip persistence
  group('Property 3: Sync queue round-trip persistence', () {
    /// Helper to create a fresh in-memory database for each Glados iteration
    Future<(Database, SyncQueueDao)> createRoundTripDb() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE sync_queue (
                id TEXT PRIMARY KEY,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                operation_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at TEXT NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0,
                status TEXT NOT NULL DEFAULT 'pending'
              )
            ''');
          },
        ),
      );
      return (db, SyncQueueDao(db));
    }

    /// **Validates: Requirements 3.2**
    ///
    /// For any valid SyncMutation, enqueueing it and then retrieving
    /// pending mutations SHALL yield a mutation with all fields preserved.
    Glados2(
      any.intInRange(0, 3),
      any.intInRange(0, 2),
    ).test(
      'enqueue then getPending preserves all mutation fields',
      (entityTypeIndex, operationTypeIndex) async {
        final (roundTripDb, roundTripDao) = await createRoundTripDb();
        try {
          final entityTypes = ['exercise', 'workout', 'profile', 'progress'];
          final operationTypes = ['create', 'update', 'delete'];

          const uuid = Uuid();
          final mutationId = uuid.v4();
          final entityId = uuid.v4();
          final createdAt = DateTime(2024, 3, 15, 10, 30, 0);
          final entityType = entityTypes[entityTypeIndex];
          final operationType = operationTypes[operationTypeIndex];
          final payload = {
            'field1': 'value-$entityTypeIndex',
            'field2': operationTypeIndex * 42,
            'nested': {'key': 'data-$mutationId'},
          };

          final original = SyncMutation(
            id: mutationId,
            entityType: entityType,
            entityId: entityId,
            operationType: operationType,
            payload: payload,
            createdAt: createdAt,
            retryCount: 0,
            status: SyncStatus.pending,
          );

          // Enqueue the mutation
          await roundTripDao.enqueue(original);

          // Retrieve pending mutations
          final pending = await roundTripDao.getPending();

          // Verify exactly one mutation was retrieved
          expect(pending.length, equals(1));

          final retrieved = pending.first;

          // Verify all fields match the original
          expect(retrieved.id, equals(original.id));
          expect(retrieved.entityType, equals(original.entityType));
          expect(retrieved.entityId, equals(original.entityId));
          expect(retrieved.operationType, equals(original.operationType));
          expect(retrieved.payload, equals(original.payload));
          expect(retrieved.createdAt, equals(original.createdAt));
          expect(retrieved.retryCount, equals(original.retryCount));
          expect(retrieved.status, equals(original.status));
        } finally {
          await roundTripDb.close();
        }
      },
    );

    Glados(any.intInRange(1, 10)).test(
      'multiple enqueued mutations all preserve their fields through round-trip',
      (count) async {
        final (roundTripDb, roundTripDao) = await createRoundTripDb();
        try {
          final entityTypes = ['exercise', 'workout', 'profile', 'progress'];
          final operationTypes = ['create', 'update', 'delete'];
          final baseTime = DateTime(2024, 5, 1, 8, 0, 0);

          final originals = List.generate(count, (i) {
            return SyncMutation(
              id: 'rt-mutation-$i',
              entityType: entityTypes[i % entityTypes.length],
              entityId: 'entity-rt-$i',
              operationType: operationTypes[i % operationTypes.length],
              payload: {'index': i, 'data': 'payload-$i'},
              createdAt: baseTime.add(Duration(seconds: i)),
              retryCount: 0,
              status: SyncStatus.pending,
            );
          });

          // Enqueue all mutations
          for (final mutation in originals) {
            await roundTripDao.enqueue(mutation);
          }

          // Retrieve all pending mutations
          final pending = await roundTripDao.getPending();

          expect(pending.length, equals(count));

          // Verify each retrieved mutation matches the original
          for (int i = 0; i < count; i++) {
            final original = originals[i];
            final retrieved = pending[i];

            expect(retrieved.id, equals(original.id),
                reason: 'id mismatch at index $i');
            expect(retrieved.entityType, equals(original.entityType),
                reason: 'entityType mismatch at index $i');
            expect(retrieved.entityId, equals(original.entityId),
                reason: 'entityId mismatch at index $i');
            expect(retrieved.operationType, equals(original.operationType),
                reason: 'operationType mismatch at index $i');
            expect(retrieved.payload, equals(original.payload),
                reason: 'payload mismatch at index $i');
            expect(retrieved.createdAt, equals(original.createdAt),
                reason: 'createdAt mismatch at index $i');
            expect(retrieved.retryCount, equals(original.retryCount),
                reason: 'retryCount mismatch at index $i');
            expect(retrieved.status, equals(original.status),
                reason: 'status mismatch at index $i');
          }
        } finally {
          await roundTripDb.close();
        }
      },
    );
  });

  // Feature: offline-support-and-ui-enhancements, Property 5: Successful sync removes mutation from queue
  group('Property 5: Successful sync removes mutation from queue', () {
    /// Helper to create a fresh in-memory database for each Glados iteration
    Future<(Database, SyncQueueDao)> createSyncRemoveDb() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE sync_queue (
                id TEXT PRIMARY KEY,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                operation_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at TEXT NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0,
                status TEXT NOT NULL DEFAULT 'pending'
              )
            ''');
          },
        ),
      );
      return (db, SyncQueueDao(db));
    }

    /// **Validates: Requirements 4.2**
    ///
    /// For any mutation that is successfully synced, the SyncQueue SHALL
    /// no longer contain that mutation after markCompleted is called.
    Glados2(
      any.intInRange(0, 3),
      any.intInRange(0, 2),
    ).test(
      'markCompleted removes mutation from getPending and pendingCount returns 0',
      (entityTypeIndex, operationTypeIndex) async {
        final (syncRemoveDb, syncRemoveDao) = await createSyncRemoveDb();
        try {
          final entityTypes = ['exercise', 'workout', 'profile', 'progress'];
          final operationTypes = ['create', 'update', 'delete'];

          final mutationId = const Uuid().v4();
          final mutation = SyncMutation(
            id: mutationId,
            entityType: entityTypes[entityTypeIndex],
            entityId: 'entity-${const Uuid().v4()}',
            operationType: operationTypes[operationTypeIndex],
            payload: {'key': 'value', 'index': entityTypeIndex},
            createdAt: DateTime(2024, 4, 10, 14, 30, 0),
            retryCount: 0,
            status: SyncStatus.pending,
          );

          // Enqueue the mutation
          await syncRemoveDao.enqueue(mutation);

          // Verify it exists in pending
          final beforePending = await syncRemoveDao.getPending();
          expect(beforePending.length, equals(1));
          expect(beforePending.first.id, equals(mutationId));

          // Mark as completed (simulating successful sync)
          await syncRemoveDao.markCompleted(mutationId);

          // Verify getPending no longer contains the mutation
          final afterPending = await syncRemoveDao.getPending();
          expect(afterPending, isEmpty,
              reason:
                  'getPending() should return empty after markCompleted is called');

          // Verify pendingCount returns 0
          final count = await syncRemoveDao.pendingCount();
          expect(count, equals(0),
              reason: 'pendingCount() should return 0 after markCompleted');
        } finally {
          await syncRemoveDb.close();
        }
      },
    );

    Glados(any.intInRange(2, 10)).test(
      'markCompleted removes only the specified mutation, leaving others pending',
      (totalCount) async {
        final (syncRemoveDb, syncRemoveDao) = await createSyncRemoveDb();
        try {
          final baseTime = DateTime(2024, 7, 1, 9, 0, 0);

          // Enqueue multiple mutations
          final mutations = List.generate(totalCount, (i) {
            return SyncMutation(
              id: 'remove-test-$i',
              entityType: 'workout',
              entityId: 'entity-$i',
              operationType: 'update',
              payload: {'data': 'value-$i'},
              createdAt: baseTime.add(Duration(seconds: i)),
              retryCount: 0,
              status: SyncStatus.pending,
            );
          });

          for (final mutation in mutations) {
            await syncRemoveDao.enqueue(mutation);
          }

          // Mark the first mutation as completed
          await syncRemoveDao.markCompleted(mutations.first.id);

          // Verify remaining mutations are still pending
          final pending = await syncRemoveDao.getPending();
          expect(pending.length, equals(totalCount - 1));

          // Verify the completed mutation is not in the list
          final pendingIds = pending.map((m) => m.id).toList();
          expect(pendingIds, isNot(contains(mutations.first.id)),
              reason:
                  'Completed mutation should not appear in getPending results');

          // Verify pendingCount matches
          final count = await syncRemoveDao.pendingCount();
          expect(count, equals(totalCount - 1));

          // Verify remaining mutations are the correct ones
          for (int i = 1; i < totalCount; i++) {
            expect(pendingIds, contains(mutations[i].id));
          }
        } finally {
          await syncRemoveDb.close();
        }
      },
    );
  });
}
