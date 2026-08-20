// Feature: database-simplification, Property 7: Frontend WorkoutHistory model serialization round-trip
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:glados/glados.dart' as glados show any;
import 'package:synchrofit/core/models/workout_history.dart';

/// **Validates: Requirements 10.2**
///
/// Property 7: Frontend WorkoutHistory model serialization round-trip
///
/// For any valid WorkoutHistory object (with completedAt datetime,
/// totalDurationSeconds, and exercisesCompleted list), calling toJson()
/// then fromJson() SHALL produce an equivalent WorkoutHistory object.
void main() {
  group('Property 7: Frontend WorkoutHistory model serialization round-trip',
      () {
    // ─────────────────────────────────────────────────────────────────────
    // Test 1: Round-trip with varying exercisesCompleted list sizes
    // ─────────────────────────────────────────────────────────────────────
    Glados3(
      glados.any.intInRange(0, 10), // number of exercises completed
      glados.any.intInRange(0, 86400), // totalDurationSeconds (0 to 24h)
      glados.any.intInRange(0, 365), // days offset for completedAt
    ).test(
      'toJson() → fromJson() produces equivalent WorkoutHistory for any valid object',
      (exerciseCount, duration, daysOffset) {
        // Generate a list of exercisesCompleted maps
        final exercisesCompleted = List.generate(exerciseCount, (i) {
          return <String, dynamic>{
            'exercise_id': i + 1,
            'exercise_name': 'Exercise_$i',
            'sets_completed': (i % 5) + 1,
            'reps_completed': (i % 12) + 1,
            'skipped': i % 3 == 0,
          };
        });

        final completedAt = DateTime(2024, 1, 1).add(Duration(days: daysOffset));

        final original = WorkoutHistory(
          id: 'wh-test-$exerciseCount-$duration',
          userId: 'user-123',
          workoutName: 'Workout_$exerciseCount',
          completedAt: completedAt,
          totalDurationSeconds: duration,
          exercisesCompleted: exercisesCompleted,
          createdAt: completedAt,
          updatedAt: completedAt,
        );

        // Perform round-trip: toJson() → fromJson()
        final json = original.toJson();
        final restored = WorkoutHistory.fromJson(json);

        // Verify equivalence using == operator
        expect(
          restored,
          equals(original),
          reason:
              'WorkoutHistory round-trip failed for exerciseCount=$exerciseCount, '
              'duration=$duration, daysOffset=$daysOffset',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 2: Round-trip preserves totalDurationSeconds across full range
    // ─────────────────────────────────────────────────────────────────────
    Glados(glados.any.intInRange(0, 7200)).test(
      'toJson() → fromJson() preserves totalDurationSeconds value',
      (duration) {
        final original = WorkoutHistory(
          id: 'wh-duration-$duration',
          userId: 'user-456',
          workoutName: 'Duration Test Workout',
          completedAt: DateTime(2024, 6, 15, 10, 30),
          totalDurationSeconds: duration,
          exercisesCompleted: [
            {
              'exercise_id': 1,
              'exercise_name': 'Push Ups',
              'sets_completed': 3,
              'reps_completed': 12,
              'skipped': false,
            },
          ],
        );

        final json = original.toJson();
        final restored = WorkoutHistory.fromJson(json);

        expect(
          restored.totalDurationSeconds,
          equals(original.totalDurationSeconds),
          reason:
              'totalDurationSeconds mismatch: expected $duration, '
              'got ${restored.totalDurationSeconds}',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 3: Round-trip preserves completedAt DateTime across dates
    // ─────────────────────────────────────────────────────────────────────
    Glados2(
      glados.any.intInRange(0, 730), // days offset from base
      glados.any.intInRange(0, 1439), // minutes within the day
    ).test(
      'toJson() → fromJson() preserves completedAt DateTime (ISO 8601)',
      (daysOffset, minutesInDay) {
        final completedAt = DateTime(2023, 1, 1)
            .add(Duration(days: daysOffset, minutes: minutesInDay));

        final original = WorkoutHistory(
          id: 'wh-date-$daysOffset-$minutesInDay',
          userId: 'user-789',
          workoutName: 'Date Test Workout',
          completedAt: completedAt,
          totalDurationSeconds: 1800,
          exercisesCompleted: [
            {
              'exercise_id': 2,
              'exercise_name': 'Squats',
              'sets_completed': 4,
              'reps_completed': 10,
              'skipped': false,
            },
          ],
        );

        final json = original.toJson();
        final restored = WorkoutHistory.fromJson(json);

        expect(
          restored.completedAt,
          equals(original.completedAt),
          reason:
              'completedAt mismatch: expected ${original.completedAt}, '
              'got ${restored.completedAt}',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 4: Round-trip with nullable createdAt/updatedAt fields
    // ─────────────────────────────────────────────────────────────────────
    Glados(glados.any.intInRange(0, 3)).test(
      'toJson() → fromJson() handles nullable createdAt/updatedAt correctly',
      (nullCase) {
        // nullCase: 0 = both null, 1 = createdAt only, 2 = updatedAt only, 3 = both present
        final baseDate = DateTime(2024, 3, 20, 14, 0);
        final DateTime? createdAt = (nullCase == 0 || nullCase == 2) ? null : baseDate;
        final DateTime? updatedAt = (nullCase == 0 || nullCase == 1) ? null : baseDate;

        final original = WorkoutHistory(
          id: 'wh-nullable-$nullCase',
          userId: 'user-nullable',
          workoutName: 'Nullable Test',
          completedAt: baseDate,
          totalDurationSeconds: 600,
          exercisesCompleted: [],
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        final json = original.toJson();
        final restored = WorkoutHistory.fromJson(json);

        expect(
          restored,
          equals(original),
          reason:
              'Round-trip failed for nullCase=$nullCase '
              '(createdAt=${createdAt == null ? "null" : "set"}, '
              'updatedAt=${updatedAt == null ? "null" : "set"})',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 5: Round-trip with varying exercise map field values
    // ─────────────────────────────────────────────────────────────────────
    Glados3(
      glados.any.intInRange(1, 20), // sets_completed
      glados.any.intInRange(1, 100), // reps_completed
      glados.any.intInRange(0, 1), // skipped (0=false, 1=true)
    ).test(
      'toJson() → fromJson() preserves exercisesCompleted map field values',
      (sets, reps, skippedInt) {
        final skipped = skippedInt == 1;

        final exercisesCompleted = [
          <String, dynamic>{
            'exercise_id': 42,
            'exercise_name': 'Bench Press',
            'sets_completed': sets,
            'reps_completed': reps,
            'skipped': skipped,
          },
        ];

        final original = WorkoutHistory(
          id: 'wh-fields-$sets-$reps-$skippedInt',
          userId: 'user-fields',
          workoutName: 'Field Test',
          completedAt: DateTime(2024, 7, 1, 9, 0),
          totalDurationSeconds: 3600,
          exercisesCompleted: exercisesCompleted,
          createdAt: DateTime(2024, 7, 1, 9, 0),
          updatedAt: DateTime(2024, 7, 1, 9, 0),
        );

        final json = original.toJson();
        final restored = WorkoutHistory.fromJson(json);

        expect(
          restored.exercisesCompleted,
          equals(original.exercisesCompleted),
          reason:
              'exercisesCompleted mismatch for sets=$sets, reps=$reps, '
              'skipped=$skipped',
        );
      },
    );
  });
}
