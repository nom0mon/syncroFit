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
            video_path TEXT
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
  String firstName = 'John',
  String lastName = 'Doe',
  int age = 25,
  double heightCm = 180.0,
  double weightKg = 75.0,
  DateTime? updatedAt,
}) {
  return UserProfile(
    userId: userId,
    firstName: firstName,
    lastName: lastName,
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
        onRefreshCaches: ({bool forceRefresh = false}) async {
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
      final profile = _testProfile(firstName: 'Offline User');
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
      final profile1 = _testProfile(firstName: 'First Edit');
      await cachingProfileRepo.saveProfile(profile1);

      // Small delay to ensure distinct timestamps
      await Future.delayed(const Duration(milliseconds: 10));

      final profile2 = _testProfile(firstName: 'Second Edit');
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
      final profile = _testProfile(firstName: 'Event Test');
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
        onRefreshCaches: ({bool forceRefresh = false}) async {},
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
        firstName: 'Original Name',
        updatedAt: DateTime(2024, 6, 1, 10, 0, 0),
      );
      await profileDao.upsert(initialProfile);

      // Step 2: Edit profile while offline
      final editedProfile = _testProfile(
        firstName: 'Edited Offline',
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
        firstName: 'Original',
        updatedAt: oldServerTime,
      );
      await profileDao.upsert(initialProfile);

      // Step 2: Edit while offline (mutation timestamp will be "now")
      final editedProfile = _testProfile(firstName: 'Local Edit', age: 28);
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
      await cachingProfileRepo
          .updateProfile(_testProfile(firstName: 'Conflict'));

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
          videoPath: '',
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
          videoPath: '',
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
          videoPath: '',
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
          videoPath: '',
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
          videoPath: '',
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
          videoPath: '',
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
          videoPath: '',
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
          videoPath: '',
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

  // ─────────────────────────────────────────────────────────────────────────
  // Additional integration tests for Requirements 4.1, 4.5, 5.2, 5.3, 8.4
  // ─────────────────────────────────────────────────────────────────────────

  group(
      'Integration: SyncEngine.initialize() auto-syncs on connectivity change',
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
        onRefreshCaches: ({bool forceRefresh = false}) async {
          refreshCachesCalled = true;
        },
      );

      registerFallbackValue(Uri());
    });

    tearDown(() async {
      syncEngine.dispose();
      connectivity.dispose();
      await database.close();
    });

    test(
        'initialize() subscribes to connectivity stream and auto-processes queue '
        'when transitioning offline→online (Req 4.1)', () async {
      // Step 1: Enqueue a mutation while offline
      final profile = _testProfile(firstName: 'Auto Sync User');
      await cachingProfileRepo.saveProfile(profile);

      final pending = await syncQueue.getPending();
      expect(pending.length, equals(1));

      // Step 2: Mock Dio to return success
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 201,
            data: {'data': profile.toJson()},
          ));

      // Step 3: Initialize the sync engine (starts listening)
      syncEngine.initialize();

      // Step 4: Transition to online — should auto-trigger processQueue
      connectivity.setStatus(ConnectivityStatus.online);

      // Allow microtask queue to process the async processQueue call
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Step 5: Verify the queue was processed automatically
      final remainingPending = await syncQueue.getPending();
      expect(remainingPending, isEmpty);
      expect(refreshCachesCalled, isTrue);
    });

    test('initialize() does NOT auto-sync when status remains offline',
        () async {
      // Enqueue a mutation while offline
      final profile = _testProfile(firstName: 'Still Offline');
      await cachingProfileRepo.saveProfile(profile);

      // Mock (shouldn't be called)
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 201,
            data: {'data': {}},
          ));

      // Initialize
      syncEngine.initialize();

      // Emit offline again (no transition to online)
      connectivity.setStatus(ConnectivityStatus.offline);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Queue should still have the pending mutation
      final pending = await syncQueue.getPending();
      expect(pending.length, equals(1));
      expect(refreshCachesCalled, isFalse);
    });
  });

  group('Integration: Cache refresh contains latest backend data (Req 4.5)',
      () {
    late Database database;
    late SyncQueueDao syncQueueDao;
    late ProfileDao profileDao;
    late CacheMetadataDao cacheMetadataDao;
    late ExerciseDao exerciseDao;
    late FakeConnectivityMonitor connectivity;
    late MockDio mockDio;
    late MockProfileRepository mockRemoteProfile;
    late MockExerciseRepository mockRemoteExercise;
    late CachingProfileRepository cachingProfileRepo;
    late CachingExerciseRepository cachingExerciseRepo;
    late SyncQueue syncQueue;
    late ConflictResolver conflictResolver;
    late SyncEngineImpl syncEngine;

    setUp(() async {
      database = await _createInMemoryDatabase();
      syncQueueDao = SyncQueueDao(database);
      profileDao = ProfileDao(database);
      exerciseDao = ExerciseDao(database);
      cacheMetadataDao = CacheMetadataDao(database);

      connectivity = FakeConnectivityMonitor(
        initialStatus: ConnectivityStatus.offline,
      );
      mockDio = MockDio();
      mockRemoteProfile = MockProfileRepository();
      mockRemoteExercise = MockExerciseRepository();

      cachingProfileRepo = CachingProfileRepository(
        remote: mockRemoteProfile,
        dao: profileDao,
        cacheMetadataDao: cacheMetadataDao,
        syncQueueDao: syncQueueDao,
        connectivity: connectivity,
      );

      cachingExerciseRepo = CachingExerciseRepository(
        remote: mockRemoteExercise,
        dao: exerciseDao,
        cacheMetadataDao: cacheMetadataDao,
        connectivity: connectivity,
      );

      syncQueue = SyncQueueImpl(syncQueueDao);
      conflictResolver = ConflictResolver();

      // The onRefreshCaches callback simulates refreshing exercise cache
      // from backend (like the real app wiring would do)
      syncEngine = SyncEngineImpl(
        syncQueue: syncQueue,
        conflictResolver: conflictResolver,
        connectivityMonitor: connectivity,
        dio: mockDio,
        onRefreshCaches: ({bool forceRefresh = false}) async {
          // Simulate what the real refreshCaches does: fetch fresh data
          // from remote and persist to local cache
          connectivity.setStatus(ConnectivityStatus.online);
          await cachingExerciseRepo.getAll();
        },
      );

      registerFallbackValue(Uri());
    });

    tearDown(() async {
      syncEngine.dispose();
      connectivity.dispose();
      await database.close();
    });

    test(
        'after sync completes, refreshCaches fetches latest data from backend '
        'and local cache reflects the updated data (Req 4.5)', () async {
      // Step 1: Seed stale exercise data in cache
      const staleExercise = Exercise(
        id: 'ex-1',
        name: 'Old Push-ups',
        muscleGroup: 'chest',
        difficulty: DifficultyLevel.beginner,
        instructions: ['Old instructions'],
        defaultDurationSeconds: 60,
        defaultSets: 3,
        defaultReps: 10,
        videoPath: '',
      );
      await exerciseDao.upsertAll([staleExercise]);
      // Mark cache as stale so remote will be called during refresh
      await cacheMetadataDao.updateLastSynced(
        'exercises',
        DateTime.now().subtract(const Duration(minutes: 20)),
      );

      // Step 2: Enqueue a mutation while offline
      final profile = _testProfile(firstName: 'Refresh Test');
      await cachingProfileRepo.saveProfile(profile);

      // Step 3: Mock Dio for sync processing
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 201,
            data: {'data': {}},
          ));

      // Step 4: Mock remote exercise repo to return fresh data
      const freshExercise = Exercise(
        id: 'ex-1',
        name: 'Updated Push-ups',
        muscleGroup: 'chest',
        difficulty: DifficultyLevel.intermediate,
        instructions: ['New improved instructions'],
        defaultDurationSeconds: 45,
        defaultSets: 4,
        defaultReps: 15,
        videoPath: '',
      );
      when(() => mockRemoteExercise.getAll())
          .thenAnswer((_) async => const Success([freshExercise]));

      // Step 5: Switch to online and process queue
      connectivity.setStatus(ConnectivityStatus.online);
      await syncEngine.processQueue();

      // Step 6: Verify local cache now contains the fresh data from backend
      final cachedExercises = await exerciseDao.getAll();
      expect(cachedExercises.length, equals(1));
      expect(cachedExercises.first.name, equals('Updated Push-ups'));
      expect(cachedExercises.first.difficulty,
          equals(DifficultyLevel.intermediate));
      expect(cachedExercises.first.defaultReps, equals(15));
    });
  });

  group(
      'Integration: Profile PATCH payload correctness and conflict notification',
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
        onRefreshCaches: ({bool forceRefresh = false}) async {},
      );

      registerFallbackValue(Uri());
    });

    tearDown(() async {
      syncEngine.dispose();
      connectivity.dispose();
      await database.close();
    });

    test(
        'offline profile update queues PATCH mutation with only dirty fields '
        '(Req 5.2)', () async {
      // Step 1: Seed an initial profile in the cache
      final initialProfile = _testProfile(
        firstName: 'Original Name',
        age: 25,
        heightCm: 180.0,
        weightKg: 75.0,
        updatedAt: DateTime(2024, 6, 1),
      );
      await profileDao.upsert(initialProfile);

      // Step 2: Edit only name and age while offline
      final editedProfile = _testProfile(
        firstName: 'New Name',
        age: 30,
        heightCm: 180.0, // unchanged
        weightKg: 75.0, // unchanged
      );
      await cachingProfileRepo.updateProfile(editedProfile);

      // Step 3: Verify the mutation payload contains only the dirty fields
      final pending = await syncQueue.getPending();
      expect(pending.length, equals(1));

      final mutation = pending.first;
      expect(mutation.operationType, equals('update'));
      expect(mutation.entityType, equals('profile'));

      // Payload should contain only changed fields + updated_at
      final payload = mutation.payload;
      expect(payload.containsKey('first_name'), isTrue);
      expect(payload['first_name'], equals('New Name'));
      expect(payload.containsKey('age'), isTrue);
      expect(payload['age'], equals(30));
      expect(payload.containsKey('updated_at'), isTrue);

      // Unchanged fields should NOT be in the payload
      expect(payload.containsKey('height_cm'), isFalse);
      expect(payload.containsKey('weight_kg'), isFalse);
      expect(payload.containsKey('user_id'), isFalse);
    });

    test(
        'conflict where server wins emits conflictDetected event for user '
        'notification (Req 5.3)', () async {
      // Step 1: Seed profile and edit offline
      final initialProfile = _testProfile(
        firstName: 'Original',
        updatedAt: DateTime(2024, 6, 1),
      );
      await profileDao.upsert(initialProfile);

      final editedProfile = _testProfile(firstName: 'Offline Edit');
      await cachingProfileRepo.updateProfile(editedProfile);

      // Step 2: Server has a newer timestamp (server wins)
      final newerServerTime = DateTime.now().add(const Duration(hours: 2));
      when(() => mockDio.patch(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
            data: {
              'data': {
                'updated_at': newerServerTime.toIso8601String(),
              },
            },
          ));

      // Step 3: Collect sync events
      final events = <SyncEvent>[];
      syncEngine.syncEvents.listen(events.add);

      // Step 4: Process queue
      connectivity.setStatus(ConnectivityStatus.online);
      await syncEngine.processQueue();
      await Future<void>.delayed(Duration.zero);

      // Step 5: Verify conflictDetected event was emitted (user notification)
      expect(events, contains(SyncEvent.conflictDetected));

      // Step 6: Verify the mutation is removed (discarded because server wins)
      final remaining = await syncQueue.getPending();
      expect(remaining, isEmpty);
    });

    test(
        'sync result reports conflicts correctly so UI can notify user '
        'about overridden changes (Req 5.3)', () async {
      // Seed profile and enqueue two mutations (one will conflict)
      final initialProfile = _testProfile(
        firstName: 'Base',
        updatedAt: DateTime(2024, 1, 1),
      );
      await profileDao.upsert(initialProfile);

      // First mutation: will succeed
      final profile1 = _testProfile(firstName: 'First Edit');
      await cachingProfileRepo.saveProfile(profile1);

      // Second mutation: will conflict
      final profile2 = _testProfile(firstName: 'Second Edit', age: 35);
      await cachingProfileRepo.updateProfile(profile2);

      final pending = await syncQueue.getPending();
      expect(pending.length, equals(2));

      // Mock: first call succeeds, second call returns 409
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async {
        return Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 201,
          data: {'data': {}},
        );
      });

      final newerServerTime = DateTime.now().add(const Duration(days: 1));
      when(() => mockDio.patch(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
            data: {
              'data': {
                'updated_at': newerServerTime.toIso8601String(),
              },
            },
          ));

      // Process
      connectivity.setStatus(ConnectivityStatus.online);
      final syncResult = await syncEngine.processQueue();

      // Verify mixed results: 1 success, 1 conflict
      expect(syncResult.successful, equals(1));
      expect(syncResult.conflicts, equals(1));
      expect(syncResult.failed, equals(0));

      // All mutations cleared from queue
      final remainingPending = await syncQueue.getPending();
      expect(remainingPending, isEmpty);
    });
  });

  group(
      'Integration: Tab navigation preserves state with cached data (Req 8.4)',
      () {
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

    test(
        'cached data remains available across multiple reads without remote calls '
        '— simulating tab re-entry with fresh cache (Req 8.4)', () async {
      // Seed exercises in cache
      final exercises = [
        const Exercise(
          id: 'ex-1',
          name: 'Push-ups',
          muscleGroup: 'chest',
          difficulty: DifficultyLevel.beginner,
          instructions: ['Push up'],
          defaultDurationSeconds: 60,
          defaultSets: 3,
          defaultReps: 12,
          videoPath: '',
        ),
        const Exercise(
          id: 'ex-2',
          name: 'Pull-ups',
          muscleGroup: 'back',
          difficulty: DifficultyLevel.intermediate,
          instructions: ['Pull up'],
          defaultDurationSeconds: 60,
          defaultSets: 3,
          defaultReps: 8,
          videoPath: '',
        ),
      ];
      await exerciseDao.upsertAll(exercises);
      await cacheMetadataDao.updateLastSynced('exercises', DateTime.now());

      // Simulate "navigating to tab" — first read
      final firstRead = await cachingExerciseRepo.getAll();
      expect(firstRead, isA<Success<List<Exercise>, AppError>>());
      expect((firstRead as Success<List<Exercise>, AppError>).value.length,
          equals(2));

      // Apply a filter (simulating user selecting muscle group filter)
      final filteredRead =
          await cachingExerciseRepo.filterByMuscleGroup(['chest']);
      expect(filteredRead, isA<Success<List<Exercise>, AppError>>());
      expect((filteredRead as Success<List<Exercise>, AppError>).value.length,
          equals(1));
      expect((filteredRead).value.first.name, equals('Push-ups'));

      // Simulate "navigating away and back" — second read
      final secondRead = await cachingExerciseRepo.getAll();
      expect(secondRead, isA<Success<List<Exercise>, AppError>>());
      expect((secondRead as Success<List<Exercise>, AppError>).value.length,
          equals(2));

      // Re-apply same filter — data is still available (preserved in cache)
      final reFilteredRead =
          await cachingExerciseRepo.filterByMuscleGroup(['chest']);
      expect(reFilteredRead, isA<Success<List<Exercise>, AppError>>());
      expect((reFilteredRead as Success<List<Exercise>, AppError>).value.length,
          equals(1));

      // Remote should NEVER be called since cache is fresh
      verifyNever(() => mockRemoteExercise.getAll());
    });

    test(
        'search results remain consistent across multiple tab entries '
        'without cache expiration (Req 8.4)', () async {
      // Seed exercises
      final exercises = [
        const Exercise(
          id: 'ex-1',
          name: 'Bench Press',
          muscleGroup: 'chest',
          difficulty: DifficultyLevel.intermediate,
          instructions: ['Press'],
          defaultDurationSeconds: 60,
          defaultSets: 4,
          defaultReps: 8,
          videoPath: '',
        ),
        const Exercise(
          id: 'ex-2',
          name: 'Overhead Press',
          muscleGroup: 'shoulders',
          difficulty: DifficultyLevel.intermediate,
          instructions: ['Press overhead'],
          defaultDurationSeconds: 45,
          defaultSets: 3,
          defaultReps: 10,
          videoPath: '',
        ),
        const Exercise(
          id: 'ex-3',
          name: 'Squat',
          muscleGroup: 'legs',
          difficulty: DifficultyLevel.advanced,
          instructions: ['Squat down'],
          defaultDurationSeconds: 60,
          defaultSets: 5,
          defaultReps: 5,
          videoPath: '',
        ),
      ];
      await exerciseDao.upsertAll(exercises);
      await cacheMetadataDao.updateLastSynced('exercises', DateTime.now());

      // First tab entry: search for "Press"
      final searchResult1 = await cachingExerciseRepo.search('Press');
      expect(searchResult1, isA<Success<List<Exercise>, AppError>>());
      final found1 = (searchResult1 as Success<List<Exercise>, AppError>).value;
      expect(found1.length, equals(2));

      // "Navigate away" and come back — same search yields same results
      final searchResult2 = await cachingExerciseRepo.search('Press');
      expect(searchResult2, isA<Success<List<Exercise>, AppError>>());
      final found2 = (searchResult2 as Success<List<Exercise>, AppError>).value;
      expect(found2.length, equals(2));
      expect(found2.map((e) => e.id).toSet(),
          equals(found1.map((e) => e.id).toSet()));

      // Verify no remote calls made
      verifyNever(() => mockRemoteExercise.getAll());
    });
  });
}
