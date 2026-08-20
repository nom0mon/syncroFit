// Feature: database-simplification, Property 8: Frontend Exercise DAO video_path round-trip
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:glados/glados.dart' as glados show any;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchrofit/data/local/daos/exercise_dao.dart';
import 'package:synchrofit/shared/models/enums.dart';
import 'package:synchrofit/shared/models/exercise.dart';

/// **Validates: Requirements 8.2, 11.3**
///
/// Property 8: Frontend Exercise DAO video_path round-trip
///
/// For any valid Exercise object with a non-null videoPath, inserting via the
/// Exercise DAO and reading back by ID SHALL produce an Exercise with an
/// identical videoPath value.

/// Valid muscle groups for generating exercises.
const _muscleGroups = [
  'Chest',
  'Back',
  'Legs',
  'Shoulders',
  'Arms',
  'Core',
];

/// Generates a video path in the format `assets/videos/{name}.mp4`.
String _generateVideoPath(String name) {
  final snake = name
      .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_');
  return 'assets/videos/$snake.mp4';
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database database;
  late ExerciseDao exerciseDao;

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
              video_path TEXT
            )
          ''');
        },
      ),
    );

    exerciseDao = ExerciseDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Property 8: Frontend Exercise DAO video_path round-trip', () {
    // ─── Test 1: video_path preserved through insert and read-back ───
    Glados3(
      glados.any.intInRange(0, 99), // unique id suffix
      glados.any.intInRange(0, _muscleGroups.length - 1), // muscle group index
      glados.any.intInRange(0, DifficultyLevel.values.length - 1), // difficulty index
    ).test(
      'inserting Exercise with non-null videoPath and reading back by ID preserves videoPath',
      (idSuffix, muscleGroupIndex, difficultyIndex) async {
        final name = 'Exercise $idSuffix';
        final videoPath = _generateVideoPath(name);
        final muscleGroup = _muscleGroups[muscleGroupIndex];
        final difficulty = DifficultyLevel.values[difficultyIndex];

        final exercise = Exercise(
          id: 'ex-$idSuffix',
          name: name,
          muscleGroup: muscleGroup,
          difficulty: difficulty,
          instructions: ['Step 1', 'Step 2'],
          equipment: 'Dumbbells',
          defaultDurationSeconds: 60,
          defaultSets: 3,
          defaultReps: 12,
          videoPath: videoPath,
        );

        // Insert via DAO
        await exerciseDao.upsert(exercise);

        // Read back by ID
        final retrieved = await exerciseDao.getById('ex-$idSuffix');

        expect(retrieved, isNotNull,
            reason: 'Exercise with id "ex-$idSuffix" should exist after insert');
        expect(retrieved!.videoPath, equals(videoPath),
            reason:
                'videoPath mismatch: expected "$videoPath", got "${retrieved.videoPath}"');
      },
    );

    // ─── Test 2: various video path formats preserved exactly ───
    Glados2(
      glados.any.intInRange(0, 49), // unique id suffix
      glados.any.intInRange(1, 5), // word count in name
    ).test(
      'videoPath with varying name lengths is preserved exactly through DAO round-trip',
      (idSuffix, wordCount) async {
        // Generate a multi-word name to produce different snake_case paths
        final words = List.generate(wordCount, (i) => 'Word${i + idSuffix}');
        final name = words.join(' ');
        final videoPath = _generateVideoPath(name);

        final exercise = Exercise(
          id: 'ex-multi-$idSuffix-$wordCount',
          name: name,
          muscleGroup: 'Core',
          difficulty: DifficultyLevel.beginner,
          instructions: ['Perform the exercise'],
          equipment: null,
          defaultDurationSeconds: 45,
          defaultSets: 2,
          defaultReps: 10,
          videoPath: videoPath,
        );

        await exerciseDao.upsert(exercise);
        final retrieved = await exerciseDao.getById('ex-multi-$idSuffix-$wordCount');

        expect(retrieved, isNotNull);
        expect(retrieved!.videoPath, equals(videoPath),
            reason:
                'videoPath should be preserved exactly. Expected "$videoPath", '
                'got "${retrieved.videoPath}"');
      },
    );

    // ─── Test 3: videoPath preserved through upsertAll batch operation ───
    Glados(glados.any.intInRange(1, 10)).test(
      'upsertAll preserves videoPath for all exercises in batch',
      (batchSize) async {
        final exercises = List.generate(batchSize, (i) {
          final name = 'Batch Exercise $i';
          return Exercise(
            id: 'ex-batch-$i',
            name: name,
            muscleGroup: _muscleGroups[i % _muscleGroups.length],
            difficulty: DifficultyLevel.values[i % DifficultyLevel.values.length],
            instructions: ['Do it'],
            equipment: i.isEven ? 'Barbell' : null,
            defaultDurationSeconds: 30 + i * 10,
            defaultSets: (i % 4) + 1,
            defaultReps: (i % 12) + 1,
            videoPath: _generateVideoPath(name),
          );
        });

        // Insert all via batch
        await exerciseDao.upsertAll(exercises);

        // Verify each one individually
        for (final original in exercises) {
          final retrieved = await exerciseDao.getById(original.id);
          expect(retrieved, isNotNull,
              reason: 'Exercise "${original.id}" should exist after upsertAll');
          expect(retrieved!.videoPath, equals(original.videoPath),
              reason:
                  'videoPath mismatch for "${original.id}": '
                  'expected "${original.videoPath}", got "${retrieved.videoPath}"');
        }
      },
    );

    // ─── Test 4: update (upsert) preserves new videoPath value ───
    Glados(glados.any.intInRange(0, 49)).test(
      'updating an exercise via upsert preserves the new videoPath',
      (idSuffix) async {
        final originalVideoPath = 'assets/videos/original_$idSuffix.mp4';
        final updatedVideoPath = 'assets/videos/updated_$idSuffix.mp4';

        final original = Exercise(
          id: 'ex-update-$idSuffix',
          name: 'Update Exercise $idSuffix',
          muscleGroup: 'Legs',
          difficulty: DifficultyLevel.advanced,
          instructions: ['Original instruction'],
          equipment: 'Barbell',
          defaultDurationSeconds: 90,
          defaultSets: 4,
          defaultReps: 8,
          videoPath: originalVideoPath,
        );

        // Insert original
        await exerciseDao.upsert(original);

        // Update with new videoPath
        final updated = Exercise(
          id: 'ex-update-$idSuffix',
          name: 'Update Exercise $idSuffix',
          muscleGroup: 'Legs',
          difficulty: DifficultyLevel.advanced,
          instructions: ['Original instruction'],
          equipment: 'Barbell',
          defaultDurationSeconds: 90,
          defaultSets: 4,
          defaultReps: 8,
          videoPath: updatedVideoPath,
        );

        await exerciseDao.upsert(updated);

        // Read back and verify
        final retrieved = await exerciseDao.getById('ex-update-$idSuffix');
        expect(retrieved, isNotNull);
        expect(retrieved!.videoPath, equals(updatedVideoPath),
            reason:
                'After update, videoPath should be "$updatedVideoPath", '
                'got "${retrieved.videoPath}"');
      },
    );
  });
}
