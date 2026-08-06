import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchrofit/core/network/connectivity_monitor.dart';
import 'package:synchrofit/data/caching/caching_exercise_repository.dart';
import 'package:synchrofit/data/caching/caching_profile_repository.dart';
import 'package:synchrofit/data/local/daos/cache_metadata_dao.dart';
import 'package:synchrofit/data/local/daos/exercise_dao.dart';
import 'package:synchrofit/data/local/daos/profile_dao.dart';
import 'package:synchrofit/data/local/daos/sync_queue_dao.dart';
import 'package:synchrofit/data/repositories/exercise_repository.dart';
import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/data/sync/conflict_resolver.dart';
import 'package:synchrofit/data/sync/sync_engine.dart';
import 'package:synchrofit/data/sync/sync_engine_impl.dart';
import 'package:synchrofit/data/sync/sync_queue.dart';
import 'package:synchrofit/data/sync/sync_queue_impl.dart';
import 'package:synchrofit/shared/models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockExerciseRepository extends Mock implements ExerciseRepository {}

/// A controllable ConnectivityMonitor for integration testing.
/// Allows tests to programmatically switch between online and offline states.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _currentStatus;

  FakeConnectivityMonitor({
    ConnectivityStatus initialStatus = ConnectivityStatus.offline,
  }) : _currentStatus = initialStatus;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  @override
  ConnectivityStatus get currentStatus => _currentStatus;

  @override
  Future<bool> checkServerReachability() async {
    return _currentStatus == ConnectivityStatus.online;
  }

  /// Transitions to a new connectivity status, emitting on the stream.
  void setStatus(ConnectivityStatus status) {
    _currentStatus = status;
    _controller.add(status);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Creates an in-memory SQLite database with all required tables.
Future<Database> _createInMemoryDatabase() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exercises (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            instructions TEXT NOT NULL,
            equipment TEXT,
            default_duration_seconds INTEGER NOT NULL,
            default_sets INTEGER NOT NULL,
            default_reps INTEGER NOT NULL,
            image_url TEXT
          )
        ''');

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
}

UserProfile _testProfile({
  String userId = 'user-1',
  String name = 'John Doe',
  int age = 25,
  double heightCm = 180.0,
  double weightKg = 75.0,
  DateTime? updatedAt,
}) {
  return UserProfile(
    userId: userId,
    name: name,
    age: age,
    heightCm: heightCm,
    weightKg: weightKg,
    gender: Gender.male,
    fitnessGoal: FitnessGoal.buildMuscle,
    fitnessLevel: FitnessLevel.intermediate,
    workoutPreference: WorkoutPreference.gym,
    workoutAvailability: [
      DayOfWeek.monday,
      DayOfWeek.wednesday,
      DayOfWeek.friday
    ],
    updatedAt: updatedAt,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Integration tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Integration: Offline mutation → reconnection → sync → cache refresh',
      () {
    late Database database;
    late SyncQueueDao syncQueueDao;
    late ProfileDao profileDao;
    late CacheMetadataDao cacheMetadataDao;
    late FakeConnectivityMonitor connectivity;
    late MockDio mockDio;
    late MockProfileRepository mockRemoteProfile;
    late CachingProfileRepository cachingProfileRepo;
    late SyncQueue syncQueue;
    late ConflictResolver conflictResolver;
    late SyncEngineImpl syncEngine;
    late bool refreshCachesCalled;

    setUp(() async {
      database = await _createInMemoryDatabase();
      syncQueueDao = SyncQueueDao(database);
      profileDao = ProfileDao(database);
      cacheMetadataDao = CacheMetadataDao(database);

      connectivity = FakeConnectivityMonitor(
        initialStatus: ConnectivityStatus.offline,
      );
      mockDio = MockDio();
      mockRemoteProfile = MockProfileRepository();

      cachingProfileRepo = CachingProfileRepository(
        remote: mockRemoteProfile,
        dao: profileDao,
        cacheMetadataDao: cacheMetadataDao,
        syncQueueDao: syncQueueDao,
        connectivity: connectivity,
      );

      syncQueue = SyncQueueImpl(syncQueueDao);
      conflictResolver = ConflictResolver();
      refreshCachesCalled = false;

      syncEngine = SyncEngineImpl(
        syncQueue: syncQueue,
        conflictResolver: conflictResolver,
        connectivityMonitor: connectivity,
        dio: mockDio,
        onRefreshCaches: () async {
          refreshCachesCalled = true;
        },
      );

      // Register fallback values for mocktail
      registerFallbackValue(Uri());
    });

    tearDown(() async {
      syncEngine.dispose();
      connectivity.dispose();
      await database.close();
    });

    test(
        'saves profile while offline → mutation enqueued → '
        'reconnect → sync processes queue → mutation removed', () async {
      // Step 1: Save profile while offline
      final profile = _testProfile(name: 'Offline User');
      final result = await cachingProfileRepo.saveProfile(profile);

      // Verify save succeeded locally
      expect(result, isA<Success<UserProfile, AppError>>());

      // Step 2: Verify mutation is enqueued in the sync queue
      final pending = await syncQueue.getPending();
      expect(pending.length, equals(1));
      expect(pending.first.entityType, equals('profile'));
      expect(pending.first.entityId, equals('user-1'));
      expect(pending.first.operationType, equals('create'));

      // Step 3: Mock Dio to return success when sync processes the mutation
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 201,
            data: {'data': profile.toJson()},
          ));

      // Step 4: Switch connectivity to online and process the queue
      connectivity.setStatus(ConnectivityStatus.online);

      // Process the queue manually (the engine would do this on status change)
      final syncResult = await syncEngine.processQueue();

      // Step 5: Verify the mutation was processed successfully
      expect(syncResult.successful, equals(1));
      expect(syncResult.failed, equals(0));
      expect(syncResult.conflicts, equals(0));

      // Step 6: Verify the mutation is removed from the queue
      final remainingPending = await syncQueue.getPending();
      expect(remainingPending, isEmpty);

      // Step 7: Verify refreshCaches was invoked
      expect(refreshCachesCalled, isTrue);
    });

    test('multiple offline mutations are synced in chronological order',
        () async {
      // Create three mutations at different times
      final profile1 = _testProfile(name: 'First Edit');
      await cachingProfileRepo.saveProfile(profile1);

      // Small delay to ensure distinct timestamps
      await Future.delayed(const Duration(milliseconds: 10));

      final profile2 = _testProfile(name: 'Second Edit');
      await cachingProfileRepo.updateProfile(profile2);

      // Verify two mutations are enqueued
      final pending = await syncQueue.getPending();
      expect(pending.length, equals(2));

      // Verify chronological ordering
      expect(
        pending[0].createdAt.isBefore(pending[1].createdAt) ||
            pending[0].createdAt.isAtSameMomentAs(pending[1].createdAt),
        isTrue,
      );

      // Mock Dio to return success for both mutations
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 201,
            data: {'data': {}},
          ));
      when(() => mockDio.patch(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: {'data': {}},
          ));

      // Switch to online and sync
      connectivity.setStatus(ConnectivityStatus.online);
      final syncResult = await syncEngine.processQueue();

      expect(syncResult.successful, equals(2));
      expect(syncResult.failed, equals(0));

      // Verify queue is empty
      final remaining = await syncQueue.getPending();
      expect(remaining, isEmpty);
    });

    test('sync engine emits correct events during processing', () async {
      // Save a mutation while offline
      final profile = _testProfile(name: 'Event Test');
      await cachingProfileRepo.saveProfile(profile);

      // Mock Dio to return success
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 201,
            data: {'data': {}},
          ));

      // Collect sync events
      final events = <SyncEvent>[];
      syncEngine.syncEvents.listen(events.add);

      // Switch online and process
      connectivity.setStatus(ConnectivityStatus.online);
      await syncEngine.processQueue();

      // Allow microtasks to deliver broadcast stream events
      await Future<void>.delayed(Duration.zero);

      // Verify event sequence: started, completed
      expect(events, contains(SyncEvent.started));
      expect(events, contains(SyncEvent.completed));
      expect(events.indexOf(SyncEvent.started),
          lessThan(events.indexOf(SyncEvent.completed)));
    });
  });

  group('Integration: Profile edit while offline → sync with conflict', () {
    late Database database;
    late SyncQueueDao syncQueueDao;
    late ProfileDao profileDao;
    late CacheMetadataDao cacheMetadataDao;
    late FakeConnectivityMonitor connectivity;
    late MockDio mockDio;
    late MockProfileRepository mockRemoteProfile;
    late CachingProfileRepository cachingProfileRepo;
    late SyncQueue syncQueue;
    late ConflictResolver conflictResolver;
    late SyncEngineImpl syncEngine;

    setUp(() async {
      database = await _createInMemoryDatabase();
      syncQueueDao = SyncQueueDao(database);
      profileDao = ProfileDao(database);
      cacheMetadataDao = CacheMetadataDao(database);

      connectivity = FakeConnectivityMonitor(
        initialStatus: ConnectivityStatus.offline,
      );
      mockDio = MockDio();
      mockRemoteProfile = MockProfileRepository();

      cachingProfileRepo = CachingProfileRepository(
        remote: mockRemoteProfile,
        dao: profileDao,
        cacheMetadataDao: cacheMetadataDao,
        syncQueueDao: syncQueueDao,
        connectivity: connectivity,
      );

      syncQueue = SyncQueueImpl(syncQueueDao);
      conflictResolver = ConflictResolver();

      syncEngine = SyncEngineImpl(
        syncQueue: syncQueue,
        conflictResolver: conflictResolver,
        connectivityMonitor: connectivity,
        dio: mockDio,
        onRefreshCaches: () async {},
      );

      registerFallbackValue(Uri());
    });

    tearDown(() async {
      syncEngine.dispose();
      connectivity.dispose();
      await database.close();
    });

    test(
        'profile edited offline → reconnect → server returns 409 with newer timestamp '
        '→ conflict resolved as server wins → mutation marked completed',
        () async {
      // Step 1: Seed an initial profile in the local cache
      final initialProfile = _testProfile(
        name: 'Original Name',
        updatedAt: DateTime(2024, 6, 1, 10, 0, 0),
      );
      await profileDao.upsert(initialProfile);

      // Step 2: Edit profile while offline
      final editedProfile = _testProfile(
        name: 'Edited Offline',
        age: 30,
      );
      final result = await cachingProfileRepo.updateProfile(editedProfile);
      expect(result, isA<Success<UserProfile, AppError>>());

      // Step 3: Verify mutation was queued
      final pending = await syncQueue.getPending();
      expect(pending.length, equals(1));
      final mutation = pending.first;
      expect(mutation.operationType, equals('update'));

      // Step 4: Simulate reconnection → server responds with 409 conflict
      // The server has a newer updated_at timestamp (server wins)
      final serverUpdatedAt = DateTime.now().add(const Duration(hours: 1));

      when(() => mockDio.patch(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
            data: {
              'data': {
                'updated_at': serverUpdatedAt.toIso8601String(),
              },
            },
          ));

      // Step 5: Switch to online and process the queue
      connectivity.setStatus(ConnectivityStatus.online);
      final syncResult = await syncEngine.processQueue();

      // Step 6: Verify conflict was detected and resolved
      expect(syncResult.conflicts, equals(1));
      expect(syncResult.successful, equals(0));
      expect(syncResult.failed, equals(0));

      // Step 7: Verify the mutation is removed from the queue
      // (completed/discarded because server wins)
      final remainingPending = await syncQueue.getPending();
      expect(remainingPending, isEmpty);
    });

    test(
        'profile edited offline → reconnect → server returns 409 with older timestamp '
        '→ conflict resolved as local wins → mutation marked completed',
        () async {
      // Step 1: Seed profile
      final oldServerTime = DateTime(2024, 1, 1, 10, 0, 0);
      final initialProfile = _testProfile(
        name: 'Original',
        updatedAt: oldServerTime,
      );
      await profileDao.upsert(initialProfile);

      // Step 2: Edit while offline (mutation timestamp will be "now")
      final editedProfile = _testProfile(name: 'Local Edit', age: 28);
      await cachingProfileRepo.updateProfile(editedProfile);

      final pending = await syncQueue.getPending();
      expect(pending.length, equals(1));

      // Step 3: Server responds with 409 but with a much older timestamp
      // (local wins because mutation.createdAt > serverUpdatedAt)
      when(() => mockDio.patch(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
            data: {
              'data': {
                'updated_at': oldServerTime.toIso8601String(),
              },
            },
          ));

      // Step 4: Process queue
      connectivity.setStatus(ConnectivityStatus.online);
      final syncResult = await syncEngine.processQueue();

      // Step 5: Verify local wins → conflict resolved, mutation completed
      expect(syncResult.conflicts, equals(1));
      expect(syncResult.successful, equals(0));
      expect(syncResult.failed, equals(0));

      // Mutation is still removed from queue (both outcomes complete the mutation)
      final remainingPending = await syncQueue.getPending();
      expect(remainingPending, isEmpty);
    });

    test('sync engine emits conflictDetected event on 409 response', () async {
      // Seed profile and edit offline
      await profileDao.upsert(_testProfile(
        updatedAt: DateTime(2024, 6, 1),
      ));
      await cachingProfileRepo.updateProfile(_testProfile(name: 'Conflict'));

      // Mock 409 response
      when(() => mockDio.patch(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
            data: {
              'data': {
                'updated_at': DateTime.now()
                    .add(const Duration(days: 1))
                    .toIso8601String(),
              },
            },
          ));

      // Collect events
      final events = <SyncEvent>[];
      syncEngine.syncEvents.listen(events.add);

      connectivity.setStatus(ConnectivityStatus.online);
      await syncEngine.processQueue();

      expect(events, contains(SyncEvent.conflictDetected));
    });
  });

  group('Integration: Tab navigation with cached data', () {
    late Database database;
    late ExerciseDao exerciseDao;
    late CacheMetadataDao cacheMetadataDao;
    late FakeConnectivityMonitor connectivity;
    late MockExerciseRepository mockRemoteExercise;
    late CachingExerciseRepository cachingExerciseRepo;

    setUp(() async {
      database = await _createInMemoryDatabase();
      exerciseDao = ExerciseDao(database);
      cacheMetadataDao = CacheMetadataDao(database);

      connectivity = FakeConnectivityMonitor(
        initialStatus: ConnectivityStatus.online,
      );
      mockRemoteExercise = MockExerciseRepository();

      cachingExerciseRepo = CachingExerciseRepository(
        remote: mockRemoteExercise,
        dao: exerciseDao,
        cacheMetadataDao: cacheMetadataDao,
        connectivity: connectivity,
      );
    });

    tearDown(() async {
      connectivity.dispose();
      await database.close();
    });

    test('serves from cache when data is fresh (< 15 min old)', () async {
      // Step 1: Seed exercises in the cache
      final exercises = [
        const Exercise(
          id: 'ex-1',
          name: 'Push-ups',
          muscleGroup: 'chest',
          difficulty: DifficultyLevel.beginner,
          instructions: ['Get in plank position', 'Lower body', 'Push up'],
          defaultDurationSeconds: 60,
          defaultSets: 3,
          defaultReps: 12,
          imagePlaceholder: '',
        ),
        const Exercise(
          id: 'ex-2',
          name: 'Squats',
          muscleGroup: 'legs',
          difficulty: DifficultyLevel.intermediate,
          instructions: ['Stand with feet apart', 'Bend knees', 'Rise up'],
          defaultDurationSeconds: 45,
          defaultSets: 4,
          defaultReps: 10,
          imagePlaceholder: '',
        ),
      ];
      await exerciseDao.upsertAll(exercises);

      // Step 2: Mark cache as fresh (synced just now)
      await cacheMetadataDao.updateLastSynced('exercises', DateTime.now());

      // Step 3: Request exercises — should serve from cache without calling remote
      final result = await cachingExerciseRepo.getAll();

      expect(result, isA<Success<List<Exercise>, AppError>>());
      final fetched = (result as Success<List<Exercise>, AppError>).value;
      expect(fetched.length, equals(2));
      expect(fetched.map((e) => e.id), containsAll(['ex-1', 'ex-2']));

      // Step 4: Verify remote was never called
      verifyNever(() => mockRemoteExercise.getAll());
    });

    test('fetches from remote when cache is stale (> 15 min old)', () async {
      // Step 1: Seed exercises in the cache
      final cachedExercises = [
        const Exercise(
          id: 'ex-old',
          name: 'Old Exercise',
          muscleGroup: 'back',
          difficulty: DifficultyLevel.advanced,
          instructions: ['Step 1'],
          defaultDurationSeconds: 30,
          defaultSets: 2,
          defaultReps: 8,
          imagePlaceholder: '',
        ),
      ];
      await exerciseDao.upsertAll(cachedExercises);

      // Step 2: Mark cache as stale (synced 20 minutes ago)
      await cacheMetadataDao.updateLastSynced(
        'exercises',
        DateTime.now().subtract(const Duration(minutes: 20)),
      );

      // Step 3: Mock remote to return fresh data
      final freshExercises = [
        const Exercise(
          id: 'ex-new',
          name: 'Fresh Exercise',
          muscleGroup: 'arms',
          difficulty: DifficultyLevel.beginner,
          instructions: ['Curl up', 'Lower down'],
          defaultDurationSeconds: 40,
          defaultSets: 3,
          defaultReps: 15,
          imagePlaceholder: '',
        ),
      ];
      when(() => mockRemoteExercise.getAll())
          .thenAnswer((_) async => Success(freshExercises));

      // Step 4: Request exercises — should fetch from remote
      final result = await cachingExerciseRepo.getAll();

      expect(result, isA<Success<List<Exercise>, AppError>>());
      final fetched = (result as Success<List<Exercise>, AppError>).value;
      expect(fetched.length, equals(1));
      expect(fetched.first.name, equals('Fresh Exercise'));

      // Step 5: Verify remote was called
      verify(() => mockRemoteExercise.getAll()).called(1);
    });

    test('serves from cache when offline regardless of freshness', () async {
      // Switch to offline
      connectivity.setStatus(ConnectivityStatus.offline);

      // Seed exercises in the cache (stale)
      final exercises = [
        const Exercise(
          id: 'ex-offline',
          name: 'Offline Exercise',
          muscleGroup: 'shoulders',
          difficulty: DifficultyLevel.intermediate,
          instructions: ['Press up'],
          defaultDurationSeconds: 50,
          defaultSets: 3,
          defaultReps: 10,
          imagePlaceholder: '',
        ),
      ];
      await exerciseDao.upsertAll(exercises);

      // Mark cache as very stale
      await cacheMetadataDao.updateLastSynced(
        'exercises',
        DateTime.now().subtract(const Duration(hours: 2)),
      );

      // Request exercises — should serve from cache
      final result = await cachingExerciseRepo.getAll();

      expect(result, isA<Success<List<Exercise>, AppError>>());
      final fetched = (result as Success<List<Exercise>, AppError>).value;
      expect(fetched.length, equals(1));
      expect(fetched.first.name, equals('Offline Exercise'));

      // Remote should never be called while offline
      verifyNever(() => mockRemoteExercise.getAll());
    });

    test(
        'filter state is independent of cache — filtering operates on cached data',
        () async {
      // Seed diverse exercises
      final exercises = [
        const Exercise(
          id: 'ex-chest-1',
          name: 'Bench Press',
          muscleGroup: 'chest',
          difficulty: DifficultyLevel.intermediate,
          instructions: ['Lie on bench', 'Press up'],
          defaultDurationSeconds: 60,
          defaultSets: 4,
          defaultReps: 8,
          imagePlaceholder: '',
        ),
        const Exercise(
          id: 'ex-legs-1',
          name: 'Deadlift',
          muscleGroup: 'legs',
          difficulty: DifficultyLevel.advanced,
          instructions: ['Stand over bar', 'Lift'],
          defaultDurationSeconds: 90,
          defaultSets: 3,
          defaultReps: 5,
          imagePlaceholder: '',
        ),
        const Exercise(
          id: 'ex-chest-2',
          name: 'Incline Press',
          muscleGroup: 'chest',
          difficulty: DifficultyLevel.advanced,
          instructions: ['Incline bench', 'Press'],
          defaultDurationSeconds: 60,
          defaultSets: 4,
          defaultReps: 10,
          imagePlaceholder: '',
        ),
      ];
      await exerciseDao.upsertAll(exercises);

      // Mark cache as fresh
      await cacheMetadataDao.updateLastSynced('exercises', DateTime.now());

      // Filter by muscle group — should only return chest exercises
      final chestResult =
          await cachingExerciseRepo.filterByMuscleGroup(['chest']);
      expect(chestResult, isA<Success<List<Exercise>, AppError>>());
      final chestExercises =
          (chestResult as Success<List<Exercise>, AppError>).value;
      expect(chestExercises.length, equals(2));
      expect(
        chestExercises.every((e) => e.muscleGroup == 'chest'),
        isTrue,
      );

      // Filter by difficulty — should only return advanced exercises
      final advancedResult =
          await cachingExerciseRepo.filterByDifficulty('advanced');
      expect(advancedResult, isA<Success<List<Exercise>, AppError>>());
      final advancedExercises =
          (advancedResult as Success<List<Exercise>, AppError>).value;
      expect(advancedExercises.length, equals(2));
      expect(
        advancedExercises
            .every((e) => e.difficulty == DifficultyLevel.advanced),
        isTrue,
      );

      // Search by name — should find matching exercises
      final searchResult = await cachingExerciseRepo.search('Press');
      expect(searchResult, isA<Success<List<Exercise>, AppError>>());
      final searchExercises =
          (searchResult as Success<List<Exercise>, AppError>).value;
      expect(searchExercises.length, equals(2));
      expect(
        searchExercises.every((e) => e.name.contains('Press')),
        isTrue,
      );

      // Verify remote was never called (all from cache)
      verifyNever(() => mockRemoteExercise.getAll());
      verifyNever(() => mockRemoteExercise.filterByMuscleGroup(any()));
      verifyNever(() => mockRemoteExercise.filterByDifficulty(any()));
      verifyNever(() => mockRemoteExercise.search(any()));
    });
  });
}
