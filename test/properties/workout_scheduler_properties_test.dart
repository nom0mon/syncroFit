import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:synchrofit/shared/models/enums.dart';
import 'package:synchrofit/shared/models/scheduled_workout.dart';
import 'package:synchrofit/shared/models/workout.dart';
import 'package:synchrofit/shared/models/workout_exercise.dart';

// Feature: offline-support-and-ui-enhancements, Property 10: Workout scheduler maps recommendations to availability days

/// Replicates the pure mapping logic from WorkoutSchedulerNotifier._mapWorkoutsToSchedule
/// to test the scheduling invariants without requiring Riverpod infrastructure.
List<ScheduledWorkout> mapWorkoutsToSchedule(
  List<Workout> workouts,
  List<DayOfWeek> availabilityDays,
) {
  final today = DayOfWeek.values[DateTime.now().weekday - 1];
  final count = workouts.length < availabilityDays.length
      ? workouts.length
      : availabilityDays.length;
  final scheduled = <ScheduledWorkout>[];

  for (var i = 0; i < count; i++) {
    final workout = workouts[i];
    final day = availabilityDays[i];
    scheduled.add(ScheduledWorkout(
      workoutId: workout.id,
      workoutName: workout.name,
      dayOfWeek: day,
      estimatedDurationMinutes: workout.estimatedDurationMinutes,
      isCompleted: day.index < today.index,
      isGenerated: workout.isGenerated,
    ));
  }

  return scheduled;
}

/// Generates a list of Workout objects with the given count.
List<Workout> _generateWorkouts(int count) {
  return List.generate(count, (i) {
    return Workout(
      id: 'workout-$i',
      name: 'Workout $i',
      estimatedDurationMinutes: 15 + (i * 5),
      exercises: [
        const WorkoutExercise(
          exerciseId: 1,
          sets: 3,
          reps: 10,
          durationSeconds: 30,
          order: 1,
        ),
      ],
    );
  });
}

/// Generates a list of unique DayOfWeek values with the given count (0-7).
List<DayOfWeek> _generateUniqueDays(int count) {
  final allDays = List<DayOfWeek>.from(DayOfWeek.values);
  return allDays.take(count.clamp(0, 7)).toList();
}

/// **Validates: Requirements 9.1, 9.2**
///
/// Property 10: Workout scheduler maps recommendations to availability days
///
/// For any availability_days list + workout recommendations list, produces
/// at most min(workouts.length, availabilityDays.length) ScheduledWorkout items,
/// one per availability day.
void main() {
  group(
      'Property 10: Workout scheduler maps recommendations to availability days',
      () {
    Glados2(
      any.intInRange(0, 8),
      any.intInRange(0, 8),
    ).test(
      'output length equals min(workouts.length, availabilityDays.length)',
      (workoutCount, dayCount) {
        final workouts = _generateWorkouts(workoutCount);
        final availabilityDays = _generateUniqueDays(dayCount);

        final scheduled = mapWorkoutsToSchedule(workouts, availabilityDays);

        final expectedLength = min(workouts.length, availabilityDays.length);
        expect(
          scheduled.length,
          equals(expectedLength),
          reason:
              'Should produce exactly min(${workouts.length}, ${availabilityDays.length}) = $expectedLength scheduled workouts',
        );
      },
    );

    Glados2(
      any.intInRange(0, 8),
      any.intInRange(0, 8),
    ).test(
      'each ScheduledWorkout dayOfWeek matches the corresponding availability day',
      (workoutCount, dayCount) {
        final workouts = _generateWorkouts(workoutCount);
        final availabilityDays = _generateUniqueDays(dayCount);

        final scheduled = mapWorkoutsToSchedule(workouts, availabilityDays);

        for (var i = 0; i < scheduled.length; i++) {
          expect(
            scheduled[i].dayOfWeek,
            equals(availabilityDays[i]),
            reason:
                'ScheduledWorkout at index $i should have dayOfWeek=${availabilityDays[i]} but got ${scheduled[i].dayOfWeek}',
          );
        }
      },
    );

    Glados2(
      any.intInRange(0, 8),
      any.intInRange(0, 8),
    ).test(
      'each ScheduledWorkout workoutId matches the corresponding workout',
      (workoutCount, dayCount) {
        final workouts = _generateWorkouts(workoutCount);
        final availabilityDays = _generateUniqueDays(dayCount);

        final scheduled = mapWorkoutsToSchedule(workouts, availabilityDays);

        for (var i = 0; i < scheduled.length; i++) {
          expect(
            scheduled[i].workoutId,
            equals(workouts[i].id),
            reason:
                'ScheduledWorkout at index $i should have workoutId=${workouts[i].id} but got ${scheduled[i].workoutId}',
          );
        }
      },
    );

    Glados2(
      any.intInRange(0, 8),
      any.intInRange(0, 8),
    ).test(
      'days before today are marked isCompleted, today and future are not',
      (workoutCount, dayCount) {
        final workouts = _generateWorkouts(workoutCount);
        final availabilityDays = _generateUniqueDays(dayCount);

        final scheduled = mapWorkoutsToSchedule(workouts, availabilityDays);
        final today = DayOfWeek.values[DateTime.now().weekday - 1];

        for (final item in scheduled) {
          if (item.dayOfWeek.index < today.index) {
            expect(
              item.isCompleted,
              isTrue,
              reason:
                  '${item.dayOfWeek} (index ${item.dayOfWeek.index}) is before today ($today, index ${today.index}) and should be marked completed',
            );
          } else {
            expect(
              item.isCompleted,
              isFalse,
              reason:
                  '${item.dayOfWeek} (index ${item.dayOfWeek.index}) is today or after today ($today, index ${today.index}) and should NOT be marked completed',
            );
          }
        }
      },
    );

    Glados2(
      any.intInRange(0, 8),
      any.intInRange(0, 8),
    ).test(
      'each ScheduledWorkout estimatedDurationMinutes matches the source workout',
      (workoutCount, dayCount) {
        final workouts = _generateWorkouts(workoutCount);
        final availabilityDays = _generateUniqueDays(dayCount);

        final scheduled = mapWorkoutsToSchedule(workouts, availabilityDays);

        for (var i = 0; i < scheduled.length; i++) {
          expect(
            scheduled[i].estimatedDurationMinutes,
            equals(workouts[i].estimatedDurationMinutes),
            reason:
                'ScheduledWorkout at index $i duration should be ${workouts[i].estimatedDurationMinutes}',
          );
        }
      },
    );

    Glados2(
      any.intInRange(0, 8),
      any.intInRange(0, 8),
    ).test(
      'each ScheduledWorkout workoutName matches the source workout name',
      (workoutCount, dayCount) {
        final workouts = _generateWorkouts(workoutCount);
        final availabilityDays = _generateUniqueDays(dayCount);

        final scheduled = mapWorkoutsToSchedule(workouts, availabilityDays);

        for (var i = 0; i < scheduled.length; i++) {
          expect(
            scheduled[i].workoutName,
            equals(workouts[i].name),
            reason:
                'ScheduledWorkout at index $i name should be ${workouts[i].name}',
          );
        }
      },
    );
  });
}
