// Feature: database-simplification, Property 6: Frontend Workout model and DAO serialization round-trip
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:synchrofit/shared/models/workout.dart';
import 'package:synchrofit/shared/models/workout_exercise.dart';

/// **Validates: Requirements 9.2, 9.3, 11.4**
///
/// Property 6: Frontend Workout model and DAO serialization round-trip
///
/// For any valid Workout object (with exercises list, isGenerated flag,
/// dayOfWeek, and userId), serializing it to JSON via toJson() and
/// deserializing via fromJson() SHALL produce an equivalent Workout object
/// with identical exercises list and metadata.

/// Valid days of the week for the dayOfWeek field.
const _validDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

void main() {
  group('Property 6: Frontend Workout model and DAO serialization round-trip',
      () {
    // Test with varying exercise list sizes and workout metadata
    Glados3(
      any.intInRange(0, 10), // number of exercises
      any.intInRange(0, 1), // isGenerated flag (0 = false, 1 = true)
      any.intInRange(0, 7), // dayOfWeek index (0 = null, 1-7 = day)
    ).test(
      'toJson() → fromJson() produces equivalent Workout object',
      (exerciseCount, isGeneratedInt, dayOfWeekIndex) {
        final isGenerated = isGeneratedInt == 1;
        final dayOfWeek =
            dayOfWeekIndex == 0 ? null : _validDays[dayOfWeekIndex - 1];

        // Generate exercises with deterministic but varied values
        final exercises = List.generate(exerciseCount, (i) {
          return WorkoutExercise(
            exerciseId: i + 1,
            sets: (i % 5) + 1, // 1..5
            reps: (i % 15) + 1, // 1..15
            durationSeconds: (i + 1) * 15, // 15, 30, 45...
            order: i + 1,
          );
        });

        final workout = Workout(
          id: 'workout-$exerciseCount-$isGeneratedInt-$dayOfWeekIndex',
          userId: 'user-123',
          name: 'Test Workout $exerciseCount',
          dayOfWeek: dayOfWeek,
          estimatedDurationMinutes: 30 + exerciseCount * 5,
          exercises: exercises,
          isGenerated: isGenerated,
          createdAt: DateTime(2024, 6, 15, 10, 30, 0),
          updatedAt: DateTime(2024, 6, 15, 11, 0, 0),
        );

        // Serialize to JSON and deserialize back
        final json = workout.toJson();
        final restored = Workout.fromJson(json);

        // Verify round-trip equivalence
        expect(restored, equals(workout),
            reason:
                'Workout round-trip failed for exerciseCount=$exerciseCount, '
                'isGenerated=$isGenerated, dayOfWeek=$dayOfWeek');
      },
    );

    // Test with randomized exercise field values
    Glados3(
      any.intInRange(1, 20), // sets
      any.intInRange(1, 100), // reps
      any.intInRange(0, 600), // durationSeconds
    ).test(
      'toJson() → fromJson() preserves WorkoutExercise field values',
      (sets, reps, durationSeconds) {
        final exercise = WorkoutExercise(
          exerciseId: 42,
          sets: sets,
          reps: reps,
          durationSeconds: durationSeconds,
          order: 1,
        );

        final workout = Workout(
          id: 'workout-field-test',
          userId: 'user-456',
          name: 'Field Test Workout',
          dayOfWeek: 'Monday',
          estimatedDurationMinutes: 45,
          exercises: [exercise],
          isGenerated: true,
          createdAt: DateTime(2024, 1, 1, 8, 0, 0),
          updatedAt: DateTime(2024, 1, 1, 9, 0, 0),
        );

        final json = workout.toJson();
        final restored = Workout.fromJson(json);

        expect(restored, equals(workout),
            reason: 'Round-trip failed for sets=$sets, reps=$reps, '
                'durationSeconds=$durationSeconds');

        // Also verify exercise fields individually
        expect(restored.exercises.length, equals(1));
        expect(restored.exercises[0].sets, equals(sets));
        expect(restored.exercises[0].reps, equals(reps));
        expect(restored.exercises[0].durationSeconds, equals(durationSeconds));
        expect(restored.exercises[0].exerciseId, equals(42));
        expect(restored.exercises[0].order, equals(1));
      },
    );

    // Test with nullable userId
    Glados2(
      any.intInRange(0, 1), // 0 = null userId, 1 = non-null userId
      any.intInRange(1, 8), // exercise count
    ).test(
      'toJson() → fromJson() handles nullable userId correctly',
      (userIdFlag, exerciseCount) {
        final userId = userIdFlag == 0 ? null : 'user-$userIdFlag';

        final exercises = List.generate(exerciseCount, (i) {
          return WorkoutExercise(
            exerciseId: (i + 1) * 10,
            sets: 3,
            reps: 12,
            durationSeconds: 45,
            order: i + 1,
          );
        });

        final workout = Workout(
          id: 'workout-nullable-$userIdFlag',
          userId: userId,
          name: 'Nullable Test',
          dayOfWeek: 'Wednesday',
          estimatedDurationMinutes: 60,
          exercises: exercises,
          isGenerated: false,
          createdAt: DateTime(2024, 3, 10, 14, 0, 0),
          updatedAt: DateTime(2024, 3, 10, 15, 0, 0),
        );

        final json = workout.toJson();
        final restored = Workout.fromJson(json);

        expect(restored, equals(workout),
            reason: 'Round-trip failed for userId=$userId');
        expect(restored.userId, equals(userId));
        expect(restored.exercises.length, equals(exerciseCount));
      },
    );

    // Test with nullable createdAt and updatedAt
    Glados2(
      any.intInRange(0, 1), // 0 = null createdAt, 1 = non-null
      any.intInRange(0, 1), // 0 = null updatedAt, 1 = non-null
    ).test(
      'toJson() → fromJson() handles nullable timestamps correctly',
      (createdAtFlag, updatedAtFlag) {
        final createdAt =
            createdAtFlag == 0 ? null : DateTime(2024, 5, 20, 8, 0, 0);
        final updatedAt =
            updatedAtFlag == 0 ? null : DateTime(2024, 5, 20, 9, 30, 0);

        final workout = Workout(
          id: 'workout-timestamps',
          userId: 'user-789',
          name: 'Timestamp Test',
          dayOfWeek: 'Friday',
          estimatedDurationMinutes: 30,
          exercises: [
            const WorkoutExercise(
              exerciseId: 1,
              sets: 3,
              reps: 10,
              durationSeconds: 60,
              order: 1,
            ),
          ],
          isGenerated: false,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        final json = workout.toJson();
        final restored = Workout.fromJson(json);

        expect(restored, equals(workout),
            reason:
                'Round-trip failed for createdAt=$createdAt, updatedAt=$updatedAt');
        expect(restored.createdAt, equals(createdAt));
        expect(restored.updatedAt, equals(updatedAt));
      },
    );

    // Test with varying exerciseId values
    Glados(any.intInRange(1, 1000)).test(
      'toJson() → fromJson() preserves exerciseId across range',
      (exerciseId) {
        final workout = Workout(
          id: 'workout-eid-$exerciseId',
          userId: 'user-test',
          name: 'ExerciseId Range Test',
          dayOfWeek: 'Saturday',
          estimatedDurationMinutes: 20,
          exercises: [
            WorkoutExercise(
              exerciseId: exerciseId,
              sets: 4,
              reps: 8,
              durationSeconds: 30,
              order: 1,
            ),
          ],
          isGenerated: true,
          createdAt: DateTime(2024, 2, 14, 6, 0, 0),
          updatedAt: DateTime(2024, 2, 14, 7, 0, 0),
        );

        final json = workout.toJson();
        final restored = Workout.fromJson(json);

        expect(restored, equals(workout),
            reason: 'Round-trip failed for exerciseId=$exerciseId');
        expect(restored.exercises[0].exerciseId, equals(exerciseId));
      },
    );
  });
}
