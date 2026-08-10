// Feature: offline-support-and-ui-enhancements, Property 9: Exercise filtering preserves existing behavior
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:mocktail/mocktail.dart' hide any;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchrofit/core/network/connectivity_monitor.dart';
import 'package:synchrofit/data/caching/caching_exercise_repository.dart';
import 'package:synchrofit/data/local/daos/cache_metadata_dao.dart';
import 'package:synchrofit/data/local/daos/exercise_dao.dart';
import 'package:synchrofit/data/repositories/exercise_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// **Validates: Requirements 8.5**
///
/// Property 9: Exercise filtering preserves existing behavior
///
/// For any combination of muscle group filters, difficulty filter, and search
/// query applied to an exercise list, the filtered results SHALL be a subset
/// of all exercises where each result matches ALL active filter criteria
/// (AND logic across filter types, OR logic within muscle groups).

class MockConnectivityMonitor extends Mock implements ConnectivityMonitor {}

class MockExerciseRepository extends Mock implements ExerciseRepository {}

/// A predefined set of exercises covering different muscle groups and difficulties.
final _allExercises = [
  const Exercise(
    id: '1',
    name: 'Bench Press',
    muscleGroup: 'Chest',
    difficulty: DifficultyLevel.intermediate,
    instructions: ['Lie on bench', 'Press bar up'],
    equipment: 'Barbell',
    defaultDurationSeconds: 60,
    defaultSets: 3,
    defaultReps: 10,
    imagePlaceholder: 'bench_press.png',
  ),
  const Exercise(
    id: '2',
    name: 'Push Up',
    muscleGroup: 'Chest',
    difficulty: DifficultyLevel.beginner,
    instructions: ['Get into plank', 'Lower body', 'Push up'],
    equipment: null,
    defaultDurationSeconds: 45,
    defaultSets: 3,
    defaultReps: 15,
    imagePlaceholder: 'push_up.png',
  ),
  const Exercise(
    id: '3',
    name: 'Deadlift',
    muscleGroup: 'Back',
    difficulty: DifficultyLevel.advanced,
    instructions: ['Stand with bar', 'Lift with hips'],
    equipment: 'Barbell',
    defaultDurationSeconds: 90,
    defaultSets: 4,
    defaultReps: 5,
    imagePlaceholder: 'deadlift.png',
  ),
  const Exercise(
    id: '4',
    name: 'Pull Up',
    muscleGroup: 'Back',
    difficulty: DifficultyLevel.intermediate,
    instructions: ['Hang from bar', 'Pull up'],
    equipment: 'Pull-up bar',
    defaultDurationSeconds: 60,
    defaultSets: 3,
    defaultReps: 8,
    imagePlaceholder: 'pull_up.png',
  ),
  const Exercise(
    id: '5',
    name: 'Squat',
    muscleGroup: 'Legs',
    difficulty: DifficultyLevel.intermediate,
    instructions: ['Stand with bar on shoulders', 'Squat down'],
    equipment: 'Barbell',
    defaultDurationSeconds: 90,
    defaultSets: 4,
    defaultReps: 8,
    imagePlaceholder: 'squat.png',
  ),
  const Exercise(
    id: '6',
    name: 'Lunges',
    muscleGroup: 'Legs',
    difficulty: DifficultyLevel.beginner,
    instructions: ['Step forward', 'Lower knee'],
    equipment: null,
    defaultDurationSeconds: 60,
    defaultSets: 3,
    defaultReps: 12,
    imagePlaceholder: 'lunges.png',
  ),
  const Exercise(
    id: '7',
    name: 'Overhead Press',
    muscleGroup: 'Shoulders',
    difficulty: DifficultyLevel.intermediate,
    instructions: ['Stand with bar at shoulders', 'Press overhead'],
    equipment: 'Barbell',
    defaultDurationSeconds: 60,
    defaultSets: 3,
    defaultReps: 10,
    imagePlaceholder: 'overhead_press.png',
  ),
  const Exercise(
    id: '8',
    name: 'Lateral Raise',
    muscleGroup: 'Shoulders',
    difficulty: DifficultyLevel.beginner,
    instructions: ['Hold dumbbells', 'Raise to sides'],
    equipment: 'Dumbbells',
    defaultDurationSeconds: 45,
    defaultSets: 3,
    defaultReps: 12,
    imagePlaceholder: 'lateral_raise.png',
  ),
  const Exercise(
    id: '9',
    name: 'Bicep Curl',
    muscleGroup: 'Arms',
    difficulty: DifficultyLevel.beginner,
    instructions: ['Hold dumbbells', 'Curl up'],
    equipment: 'Dumbbells',
    defaultDurationSeconds: 45,
    defaultSets: 3,
    defaultReps: 12,
    imagePlaceholder: 'bicep_curl.png',
  ),
  const Exercise(
    id: '10',
    name: 'Plank',
    muscleGroup: 'Core',
    difficulty: DifficultyLevel.beginner,
    instructions: ['Get into plank position', 'Hold'],
    equipment: null,
    defaultDurationSeconds: 60,
    defaultSets: 3,
    defaultReps: 1,
    imagePlaceholder: 'plank.png',
  ),
];

/// All available muscle groups from the predefined exercises.
final _allMuscleGroups =
    _allExercises.map((e) => e.muscleGroup).toSet().toList();

/// Applies combined filtering logic matching the ExerciseNotifier._applyFilters()
/// implementation. This is the reference/oracle function for the property test.
///
/// - Search: case-insensitive substring match on name. Empty query matches all.
/// - Muscle groups: OR within selected groups. Empty set matches all.
/// - Difficulty: exact match. Null matches all.
List<Exercise> _applyFilters({
  required List<Exercise> exercises,
  required String searchQuery,
  required Set<String> muscleGroups,
  required DifficultyLevel? difficulty,
}) {
  final query = searchQuery.toLowerCase();
  return exercises.where((exercise) {
    // Search filter
    if (query.isNotEmpty && !exercise.name.toLowerCase().contains(query)) {
      return false;
    }
    // Muscle group filter (OR logic within groups)
    if (muscleGroups.isNotEmpty &&
        !muscleGroups.contains(exercise.muscleGroup)) {
      return false;
    }
    // Difficulty filter
    if (difficulty != null && exercise.difficulty != difficulty) {
      return false;
    }
    return true;
  }).toList();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database database;
  late ExerciseDao exerciseDao;
  late CacheMetadataDao cacheMetadataDao;
  late MockConnectivityMonitor mockConnectivity;
  late MockExerciseRepository mockRemote;
  late CachingExerciseRepository cachingRepo;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
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
              image_url TEXT NOT NULL
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

    exerciseDao = ExerciseDao(database);
    cacheMetadataDao = CacheMetadataDao(database);
    mockConnectivity = MockConnectivityMonitor();
    mockRemote = MockExerciseRepository();

    // Set up: online with fresh cache so filter methods use cached data
    when(() => mockConnectivity.currentStatus)
        .thenReturn(ConnectivityStatus.online);

    cachingRepo = CachingExerciseRepository(
      remote: mockRemote,
      dao: exerciseDao,
      cacheMetadataDao: cacheMetadataDao,
      connectivity: mockConnectivity,
    );

    // Seed the cache with all exercises and mark cache as fresh
    await exerciseDao.upsertAll(_allExercises);
    await cacheMetadataDao.updateLastSynced('exercises', DateTime.now());
  });

  tearDown(() async {
    await database.close();
  });

  group('Property 9: Exercise filtering preserves existing behavior', () {
    // ─── Combined filter property: AND logic across types, OR within muscle groups ───
    Glados3(
      any.intInRange(0, (1 << _allMuscleGroups.length) - 1), // bitmask for muscle groups
      any.intInRange(0, DifficultyLevel.values.length), // 0 = no difficulty filter
      any.intInRange(0, _allExercises.length - 1), // index to derive search query
    ).test(
      'combined filter: results are subset matching ALL criteria (AND across types, OR within groups)',
      (muscleGroupBitmask, difficultyIndex, searchExerciseIndex) async {
        // Derive muscle group selection from bitmask
        final selectedMuscleGroups = <String>{};
        for (var i = 0; i < _allMuscleGroups.length; i++) {
          if (muscleGroupBitmask & (1 << i) != 0) {
            selectedMuscleGroups.add(_allMuscleGroups[i]);
          }
        }

        // Derive difficulty filter (0 = none, 1-3 = specific level)
        final DifficultyLevel? difficulty = difficultyIndex == 0
            ? null
            : DifficultyLevel.values[difficultyIndex - 1];

        // Derive search query from an exercise name substring (first 2 chars)
        final exerciseName = _allExercises[searchExerciseIndex].name;
        final searchQuery = exerciseName.length >= 2
            ? exerciseName.substring(0, 2)
            : exerciseName;

        // Apply combined filter via repository methods individually and
        // compare with the reference oracle (AND logic)
        final expectedResults = _applyFilters(
          exercises: _allExercises,
          searchQuery: searchQuery,
          muscleGroups: selectedMuscleGroups,
          difficulty: difficulty,
        );

        // Test through repository: get search results then manually apply
        // remaining filters to verify consistency
        final searchResult = await cachingRepo.search(searchQuery);
        expect(searchResult, isA<Success<List<Exercise>, AppError>>());
        final searchExercises =
            (searchResult as Success<List<Exercise>, AppError>).value;

        // Apply muscle group filter on search results (OR within groups)
        final afterMuscleFilter = selectedMuscleGroups.isEmpty
            ? searchExercises
            : searchExercises
                .where((e) => selectedMuscleGroups.contains(e.muscleGroup))
                .toList();

        // Apply difficulty filter on the remaining results
        final afterAllFilters = difficulty == null
            ? afterMuscleFilter
            : afterMuscleFilter
                .where((e) => e.difficulty == difficulty)
                .toList();

        // Verify: combined filter results match the oracle
        final expectedIds = expectedResults.map((e) => e.id).toSet();
        final actualIds = afterAllFilters.map((e) => e.id).toSet();
        expect(
          actualIds,
          equals(expectedIds),
          reason:
              'Combined filter mismatch for muscleGroups=$selectedMuscleGroups, '
              'difficulty=$difficulty, searchQuery="$searchQuery". '
              'Expected IDs: $expectedIds, Got IDs: $actualIds',
        );

        // Verify: every result is a subset of all exercises
        final allIds = _allExercises.map((e) => e.id).toSet();
        for (final exercise in afterAllFilters) {
          expect(
            allIds.contains(exercise.id),
            isTrue,
            reason:
                'Exercise "${exercise.id}" not in original exercise list',
          );
        }

        // Verify: each result matches ALL active criteria
        for (final exercise in afterAllFilters) {
          if (searchQuery.isNotEmpty) {
            expect(
              exercise.name.toLowerCase().contains(searchQuery.toLowerCase()),
              isTrue,
              reason:
                  'Exercise "${exercise.name}" does not match search "$searchQuery"',
            );
          }
          if (selectedMuscleGroups.isNotEmpty) {
            expect(
              selectedMuscleGroups.contains(exercise.muscleGroup),
              isTrue,
              reason:
                  'Exercise "${exercise.name}" muscleGroup "${exercise.muscleGroup}" '
                  'not in $selectedMuscleGroups',
            );
          }
          if (difficulty != null) {
            expect(
              exercise.difficulty,
              equals(difficulty),
              reason:
                  'Exercise "${exercise.name}" difficulty ${exercise.difficulty} '
                  'does not match $difficulty',
            );
          }
        }
      },
    );

    // ─── Search filter property ───
    Glados(any.intInRange(0, _allExercises.length - 1)).test(
      'search results contain query in name (case-insensitive) and are a subset of all exercises',
      (exerciseIndex) async {
        final exerciseName = _allExercises[exerciseIndex].name;
        // Use first 3 chars (or full name if shorter) as the query
        final query = exerciseName.substring(
          0,
          exerciseName.length >= 3 ? 3 : exerciseName.length,
        );

        final result = await cachingRepo.search(query);

        expect(result, isA<Success<List<Exercise>, AppError>>());
        final exercises = (result as Success<List<Exercise>, AppError>).value;

        // Every result must contain the query in its name (case-insensitive)
        for (final exercise in exercises) {
          expect(
            exercise.name.toLowerCase().contains(query.toLowerCase()),
            isTrue,
            reason:
                'Exercise "${exercise.name}" does not contain query "$query"',
          );
        }

        // Results are a subset of all exercises
        final allIds = _allExercises.map((e) => e.id).toSet();
        for (final exercise in exercises) {
          expect(
            allIds.contains(exercise.id),
            isTrue,
            reason:
                'Exercise "${exercise.id}" is not in the original exercise list',
          );
        }

        // At least the source exercise should match
        expect(exercises.length, greaterThanOrEqualTo(1));
      },
    );

    // ─── Muscle group filter property ───
    Glados(any.intInRange(1, _allMuscleGroups.length)).test(
      'filterByMuscleGroup results all belong to the requested groups and are a subset',
      (groupCount) async {
        final selectedGroups = _allMuscleGroups.take(groupCount).toList();

        final result = await cachingRepo.filterByMuscleGroup(selectedGroups);

        expect(result, isA<Success<List<Exercise>, AppError>>());
        final exercises = (result as Success<List<Exercise>, AppError>).value;

        final lowerGroups = selectedGroups.map((g) => g.toLowerCase()).toSet();

        // Every result must have its muscleGroup in the selected groups
        for (final exercise in exercises) {
          expect(
            lowerGroups.contains(exercise.muscleGroup.toLowerCase()),
            isTrue,
            reason:
                'Exercise "${exercise.name}" has muscleGroup "${exercise.muscleGroup}" '
                'which is not in $selectedGroups',
          );
        }

        // Verify completeness: every exercise matching filter should be present
        final expectedIds = _allExercises
            .where((e) => lowerGroups.contains(e.muscleGroup.toLowerCase()))
            .map((e) => e.id)
            .toSet();
        final resultIds = exercises.map((e) => e.id).toSet();
        expect(resultIds, equals(expectedIds));
      },
    );

    // ─── Difficulty filter property ───
    Glados(any.intInRange(0, DifficultyLevel.values.length - 1)).test(
      'filterByDifficulty results all match the requested difficulty and are a subset',
      (difficultyIndex) async {
        final difficulty = DifficultyLevel.values[difficultyIndex];

        final result = await cachingRepo.filterByDifficulty(difficulty.name);

        expect(result, isA<Success<List<Exercise>, AppError>>());
        final exercises = (result as Success<List<Exercise>, AppError>).value;

        // Every result must have the requested difficulty
        for (final exercise in exercises) {
          expect(
            exercise.difficulty,
            equals(difficulty),
            reason:
                'Exercise "${exercise.name}" has difficulty ${exercise.difficulty} '
                'but expected $difficulty',
          );
        }

        // Verify completeness
        final expectedIds = _allExercises
            .where((e) => e.difficulty == difficulty)
            .map((e) => e.id)
            .toSet();
        final resultIds = exercises.map((e) => e.id).toSet();
        expect(resultIds, equals(expectedIds));
      },
    );

    // ─── Case insensitivity property for search ───
    Glados(any.intInRange(0, _allExercises.length - 1)).test(
      'search is case-insensitive: uppercase query matches lowercase name',
      (exerciseIndex) async {
        final exerciseName = _allExercises[exerciseIndex].name;
        final upperQuery = exerciseName.toUpperCase();

        final result = await cachingRepo.search(upperQuery);

        expect(result, isA<Success<List<Exercise>, AppError>>());
        final exercises = (result as Success<List<Exercise>, AppError>).value;

        // The exercise whose name we uppercased should be in the results
        final resultIds = exercises.map((e) => e.id).toSet();
        expect(
          resultIds.contains(_allExercises[exerciseIndex].id),
          isTrue,
          reason:
              'Exercise "${exerciseName}" should match uppercase query "$upperQuery"',
        );
      },
    );

    // ─── Empty filters return all exercises ───
    test('search with empty query returns all exercises', () async {
      final result = await cachingRepo.search('');

      expect(result, isA<Success<List<Exercise>, AppError>>());
      final exercises = (result as Success<List<Exercise>, AppError>).value;

      expect(exercises.length, equals(_allExercises.length));
    });

    // ─── Non-matching search returns empty ───
    test('search with non-matching query returns empty list', () async {
      final result = await cachingRepo.search('zzz_nonexistent_xyz');

      expect(result, isA<Success<List<Exercise>, AppError>>());
      final exercises = (result as Success<List<Exercise>, AppError>).value;

      expect(exercises, isEmpty);
    });
  });
}
