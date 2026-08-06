// Feature: offline-support-and-ui-enhancements, Property 8: Cache freshness — stale data triggers refresh
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test, any;
import 'package:glados/glados.dart' as glados show any;
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/core/network/connectivity_monitor.dart';
import 'package:synchrofit/data/caching/caching_exercise_repository.dart';
import 'package:synchrofit/data/local/daos/cache_metadata_dao.dart';
import 'package:synchrofit/data/local/daos/exercise_dao.dart';
import 'package:synchrofit/data/repositories/exercise_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────────────────────────────────────

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockExerciseDao extends Mock implements ExerciseDao {}

class MockCacheMetadataDao extends Mock implements CacheMetadataDao {}

class MockConnectivityMonitor extends Mock implements ConnectivityMonitor {}

/// **Validates: Requirements 11.1, 11.2**
///
/// Property 8: Cache freshness — stale data triggers refresh
///
/// For any cache entry whose `lastSyncedAt` is older than 15 minutes and the
/// device is online, the CachingRepository SHALL fetch fresh data from the
/// backend rather than serving the stale cache.
///
/// Conversely, if `lastSyncedAt` is less than 15 minutes ago and online,
/// the cache is served directly without calling the remote.
///
/// When offline, the remote is never called regardless of cache freshness.
void main() {
  late MockExerciseRepository mockRemote;
  late MockExerciseDao mockDao;
  late MockCacheMetadataDao mockCacheMetadataDao;
  late MockConnectivityMonitor mockConnectivity;
  late CachingExerciseRepository cachingRepo;

  final sampleExercises = [
    const Exercise(
      id: 'ex-1',
      name: 'Push Up',
      muscleGroup: 'chest',
      difficulty: DifficultyLevel.beginner,
      instructions: ['Lower body', 'Push up'],
      defaultDurationSeconds: 60,
      defaultSets: 3,
      defaultReps: 12,
      imagePlaceholder: '',
    ),
    const Exercise(
      id: 'ex-2',
      name: 'Squat',
      muscleGroup: 'legs',
      difficulty: DifficultyLevel.intermediate,
      instructions: ['Stand', 'Lower hips', 'Stand up'],
      defaultDurationSeconds: 45,
      defaultSets: 4,
      defaultReps: 10,
      imagePlaceholder: '',
    ),
  ];

  setUp(() {
    mockRemote = MockExerciseRepository();
    mockDao = MockExerciseDao();
    mockCacheMetadataDao = MockCacheMetadataDao();
    mockConnectivity = MockConnectivityMonitor();

    cachingRepo = CachingExerciseRepository(
      remote: mockRemote,
      dao: mockDao,
      cacheMetadataDao: mockCacheMetadataDao,
      connectivity: mockConnectivity,
    );

    // Default stub for DAO getAll
    when(() => mockDao.getAll()).thenAnswer((_) async => sampleExercises);

    // Default stub for remote getAll
    when(() => mockRemote.getAll())
        .thenAnswer((_) async => Success(sampleExercises));

    // Default stub for upsertAll and updateLastSynced
    when(() => mockDao.upsertAll(any())).thenAnswer((_) async {});
    when(() => mockCacheMetadataDao.updateLastSynced(any(), any()))
        .thenAnswer((_) async {});
  });

  group('Property 8: Cache freshness — stale data triggers refresh', () {
    // ─────────────────────────────────────────────────────────────────────
    // Test 1: Fresh cache (< 15 min) + online → cache served, remote NOT called
    // ─────────────────────────────────────────────────────────────────────
    Glados(glados.any.intInRange(0, 14)).test(
      'online + cache fresh (< 15 min) → serves from cache, remote NOT called',
      (minutesAgo) async {
        // Set up: online and cache was synced `minutesAgo` minutes ago (< 15)
        when(() => mockConnectivity.currentStatus)
            .thenReturn(ConnectivityStatus.online);

        final lastSynced =
            DateTime.now().subtract(Duration(minutes: minutesAgo));
        when(() => mockCacheMetadataDao.getLastSynced('exercises'))
            .thenAnswer((_) async => lastSynced);

        // Act
        final result = await cachingRepo.getAll();

        // Assert: result is Success
        expect(result, isA<Success<List<Exercise>, AppError>>());

        // Assert: DAO was called (cache served)
        verify(() => mockDao.getAll()).called(1);

        // Assert: remote was NOT called
        verifyNever(() => mockRemote.getAll());
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 2: Stale cache (> 15 min) + online → remote IS called
    // ─────────────────────────────────────────────────────────────────────
    Glados(glados.any.intInRange(16, 1440)).test(
      'online + cache stale (> 15 min) → fetches from remote',
      (minutesAgo) async {
        // Set up: online and cache was synced `minutesAgo` minutes ago (> 15)
        when(() => mockConnectivity.currentStatus)
            .thenReturn(ConnectivityStatus.online);

        final lastSynced =
            DateTime.now().subtract(Duration(minutes: minutesAgo));
        when(() => mockCacheMetadataDao.getLastSynced('exercises'))
            .thenAnswer((_) async => lastSynced);

        // Act
        final result = await cachingRepo.getAll();

        // Assert: result is Success
        expect(result, isA<Success<List<Exercise>, AppError>>());

        // Assert: remote WAS called
        verify(() => mockRemote.getAll()).called(1);
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 3: Offline (any duration) → remote NOT called, DAO is used
    // ─────────────────────────────────────────────────────────────────────
    Glados(glados.any.intInRange(0, 1440)).test(
      'offline → remote NOT called regardless of cache age, DAO is used',
      (minutesAgo) async {
        // Set up: offline
        when(() => mockConnectivity.currentStatus)
            .thenReturn(ConnectivityStatus.offline);

        final lastSynced =
            DateTime.now().subtract(Duration(minutes: minutesAgo));
        when(() => mockCacheMetadataDao.getLastSynced('exercises'))
            .thenAnswer((_) async => lastSynced);

        // Act
        final result = await cachingRepo.getAll();

        // Assert: result is Success
        expect(result, isA<Success<List<Exercise>, AppError>>());

        // Assert: DAO was called (local cache served)
        verify(() => mockDao.getAll()).called(1);

        // Assert: remote was NOT called
        verifyNever(() => mockRemote.getAll());
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 4: No cache metadata (null lastSynced) + online → remote is called
    // ─────────────────────────────────────────────────────────────────────
    test(
      'online + no cache metadata (null lastSynced) → fetches from remote',
      () async {
        when(() => mockConnectivity.currentStatus)
            .thenReturn(ConnectivityStatus.online);

        // No cache metadata exists
        when(() => mockCacheMetadataDao.getLastSynced('exercises'))
            .thenAnswer((_) async => null);

        // Act
        final result = await cachingRepo.getAll();

        // Assert: result is Success
        expect(result, isA<Success<List<Exercise>, AppError>>());

        // Assert: remote WAS called (stale/missing cache)
        verify(() => mockRemote.getAll()).called(1);
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 5: Exactly 15 min boundary — cache is considered stale
    // ─────────────────────────────────────────────────────────────────────
    test(
      'online + cache exactly 15 min old → fetches from remote (boundary)',
      () async {
        when(() => mockConnectivity.currentStatus)
            .thenReturn(ConnectivityStatus.online);

        // Exactly 15 minutes ago — the condition is < 15 min for fresh
        final lastSynced = DateTime.now().subtract(const Duration(minutes: 15));
        when(() => mockCacheMetadataDao.getLastSynced('exercises'))
            .thenAnswer((_) async => lastSynced);

        // Act
        final result = await cachingRepo.getAll();

        // Assert: result is Success
        expect(result, isA<Success<List<Exercise>, AppError>>());

        // Assert: remote WAS called (15 min is NOT fresh, threshold is strictly < 15)
        verify(() => mockRemote.getAll()).called(1);
      },
    );
  });
}
