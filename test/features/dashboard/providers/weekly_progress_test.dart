import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/models/workout_history.dart';
import 'package:synchrofit/features/dashboard/providers/dashboard_provider.dart';
import 'package:synchrofit/shared/models/workout.dart';

Workout scheduled(String id, String day, {bool accepted = true}) => Workout(
      id: id,
      name: 'Workout $id',
      dayOfWeek: day,
      estimatedDurationMinutes: 20,
      exercises: const [],
      isGenerated: true,
      isAccepted: accepted,
    );

WorkoutHistory completed(String id, DateTime date) => WorkoutHistory(
      id: id,
      userId: '1',
      workoutName: 'Workout',
      completedAt: date,
      totalDurationSeconds: 1200,
      exercisesCompleted: const [],
    );

void main() {
  test('uses unique days from the accepted schedule as the planned total', () {
    final progress = calculateWeeklyProgress(
      now: DateTime(2026, 9, 9),
      workouts: [
        scheduled('1', 'monday'),
        scheduled('2', '3'),
        scheduled('3', 'friday'),
        scheduled('duplicate', 'monday'),
        scheduled('draft', 'sunday', accepted: false),
      ],
      history: const [],
    );

    expect(progress.planned, 3);
    expect(progress.completed, 0);
  });

  test('counts unique scheduled completion days and ignores extra sessions',
      () {
    final progress = calculateWeeklyProgress(
      now: DateTime(2026, 9, 9),
      workouts: [
        scheduled('1', 'monday'),
        scheduled('2', 'wednesday'),
        scheduled('3', 'friday'),
      ],
      history: [
        completed('1', DateTime(2026, 9, 7, 8)),
        completed('2', DateTime(2026, 9, 7, 18)),
        completed('3', DateTime(2026, 9, 9, 8)),
        completed('unscheduled', DateTime(2026, 9, 8)),
        completed('previous-week', DateTime(2026, 9, 4)),
      ],
    );

    expect(progress.completed, 2);
    expect(progress.planned, 3);
  });

  test('returns zero of zero when there is no accepted schedule', () {
    final progress = calculateWeeklyProgress(
      now: DateTime(2026, 9, 9),
      workouts: [scheduled('draft', 'monday', accepted: false)],
      history: [completed('1', DateTime(2026, 9, 7))],
    );

    expect(progress.completed, 0);
    expect(progress.planned, 0);
  });
}
