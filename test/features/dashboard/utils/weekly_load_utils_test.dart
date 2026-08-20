import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/dashboard/utils/weekly_load_utils.dart';
import 'package:synchrofit/core/models/workout_history.dart';
import 'package:synchrofit/shared/models/completed_exercise.dart';

void main() {
  group('computeWeekRanges', () {
    test('returns exactly 4 week ranges', () {
      final ranges = computeWeekRanges(DateTime(2025, 1, 15)); // Wednesday
      expect(ranges.length, 4);
    });

    test('each range starts on Monday and ends on Sunday', () {
      final ranges = computeWeekRanges(DateTime(2025, 6, 18)); // Wednesday
      for (final range in ranges) {
        expect(range.start.weekday, DateTime.monday);
        expect(range.end.weekday, DateTime.sunday);
      }
    });

    test('ranges are chronologically ordered W1 oldest to W4 most recent', () {
      final ranges = computeWeekRanges(DateTime(2025, 3, 20)); // Thursday
      for (int i = 0; i < 3; i++) {
        expect(ranges[i].start.isBefore(ranges[i + 1].start), isTrue);
        expect(ranges[i].end.isBefore(ranges[i + 1].end), isTrue);
      }
    });

    test('W4 Sunday is the Sunday of or before reference date week', () {
      // Reference is Wednesday Jan 15, 2025. Its week's Sunday is Jan 19.
      final ranges = computeWeekRanges(DateTime(2025, 1, 15));
      final w4End = ranges[3].end;
      expect(w4End.weekday, DateTime.sunday);
      expect(w4End, DateTime(2025, 1, 19, 23, 59, 59));
    });

    test('covers exactly 28 consecutive days', () {
      final ranges = computeWeekRanges(DateTime(2025, 2, 10)); // Monday
      final firstDay = ranges[0].start;
      final lastDay = ranges[3].end;
      final difference = lastDay.difference(firstDay).inDays;
      // From Monday 00:00 to Sunday 23:59:59 is 27 days apart (28 days total)
      expect(difference, 27);
    });

    test('ranges are non-overlapping', () {
      final ranges = computeWeekRanges(DateTime(2025, 4, 25)); // Friday
      for (int i = 0; i < 3; i++) {
        expect(ranges[i].end.isBefore(ranges[i + 1].start), isTrue);
      }
    });

    test('reference date on Sunday makes that Sunday the W4 end', () {
      // Sunday Jan 19, 2025
      final ranges = computeWeekRanges(DateTime(2025, 1, 19));
      final w4End = ranges[3].end;
      expect(w4End, DateTime(2025, 1, 19, 23, 59, 59));
      expect(ranges[3].start, DateTime(2025, 1, 13));
    });

    test('reference date on Monday makes same week Sunday the W4 end', () {
      // Monday Jan 13, 2025 — its week's Sunday is Jan 19
      final ranges = computeWeekRanges(DateTime(2025, 1, 13));
      final w4End = ranges[3].end;
      expect(w4End, DateTime(2025, 1, 19, 23, 59, 59));
      expect(ranges[3].start, DateTime(2025, 1, 13));
    });
  });

  group('isInWeek', () {
    test('date on Monday of week start returns true', () {
      final weekStart = DateTime(2025, 1, 13); // Monday
      expect(isInWeek(DateTime(2025, 1, 13, 0, 0, 0), weekStart), isTrue);
    });

    test('date on Sunday end of week returns true', () {
      final weekStart = DateTime(2025, 1, 13); // Monday
      expect(isInWeek(DateTime(2025, 1, 19, 23, 59, 59), weekStart), isTrue);
    });

    test('date before week start returns false', () {
      final weekStart = DateTime(2025, 1, 13);
      expect(isInWeek(DateTime(2025, 1, 12, 23, 59, 59), weekStart), isFalse);
    });

    test('date after week end returns false', () {
      final weekStart = DateTime(2025, 1, 13);
      expect(isInWeek(DateTime(2025, 1, 20, 0, 0, 0), weekStart), isFalse);
    });
  });

  group('calculateWeeklyVolume', () {
    test('returns 0 for empty sessions list', () {
      final volume = calculateWeeklyVolume([], DateTime(2025, 1, 13));
      expect(volume, 0);
    });

    test('returns 0 when no sessions fall in the week', () {
      final sessions = [
        WorkoutHistory(
          id: '1',
          userId: 'u1',
          workoutName: 'Chest Day',
          completedAt: DateTime(2025, 1, 10), // Friday before the week
          totalDurationSeconds: 3600,
          exercisesCompleted: [
            const CompletedExercise(
              exerciseId: 'e1',
              exerciseName: 'Bench Press',
              setsCompleted: 3,
              repsOrDuration: 10,
            ).toJson(),
          ],
        ),
      ];
      final volume = calculateWeeklyVolume(sessions, DateTime(2025, 1, 13));
      expect(volume, 0);
    });

    test('correctly sums sets * reps for sessions in the week', () {
      final weekStart = DateTime(2025, 1, 13); // Monday
      final sessions = [
        WorkoutHistory(
          id: '1',
          userId: 'u1',
          workoutName: 'Chest Day',
          completedAt: DateTime(2025, 1, 14), // Tuesday - in week
          totalDurationSeconds: 3600,
          exercisesCompleted: [
            const CompletedExercise(
              exerciseId: 'e1',
              exerciseName: 'Bench Press',
              setsCompleted: 3,
              repsOrDuration: 10, // 30
            ).toJson(),
            const CompletedExercise(
              exerciseId: 'e2',
              exerciseName: 'Flyes',
              setsCompleted: 4,
              repsOrDuration: 12, // 48
            ).toJson(),
          ],
        ),
        WorkoutHistory(
          id: '2',
          userId: 'u1',
          workoutName: 'Leg Day',
          completedAt: DateTime(2025, 1, 16), // Thursday - in week
          totalDurationSeconds: 2400,
          exercisesCompleted: [
            const CompletedExercise(
              exerciseId: 'e3',
              exerciseName: 'Squats',
              setsCompleted: 5,
              repsOrDuration: 8, // 40
            ).toJson(),
          ],
        ),
      ];
      final volume = calculateWeeklyVolume(sessions, weekStart);
      expect(volume, 30 + 48 + 40); // 118
    });

    test('only includes sessions within the specified week', () {
      final weekStart = DateTime(2025, 1, 13); // Monday
      final sessions = [
        WorkoutHistory(
          id: '1',
          userId: 'u1',
          workoutName: 'In Week',
          completedAt: DateTime(2025, 1, 15), // Wednesday - in week
          totalDurationSeconds: 3600,
          exercisesCompleted: [
            const CompletedExercise(
              exerciseId: 'e1',
              exerciseName: 'Deadlift',
              setsCompleted: 3,
              repsOrDuration: 5, // 15
            ).toJson(),
          ],
        ),
        WorkoutHistory(
          id: '2',
          userId: 'u1',
          workoutName: 'Outside Week',
          completedAt: DateTime(2025, 1, 20), // Monday next week - outside
          totalDurationSeconds: 1800,
          exercisesCompleted: [
            const CompletedExercise(
              exerciseId: 'e2',
              exerciseName: 'Rows',
              setsCompleted: 4,
              repsOrDuration: 10, // 40 - should NOT be counted
            ).toJson(),
          ],
        ),
      ];
      final volume = calculateWeeklyVolume(sessions, weekStart);
      expect(volume, 15);
    });
  });

  group('computeBarHeights', () {
    test('returns empty list for empty volumes', () {
      expect(computeBarHeights([], 200.0), isEmpty);
    });

    test('all zero volumes return minimum height of 4.0', () {
      final heights = computeBarHeights([0, 0, 0, 0], 200.0);
      expect(heights, [4.0, 4.0, 4.0, 4.0]);
    });

    test('max volume bar gets full chart height', () {
      final heights = computeBarHeights([50, 100, 75, 25], 200.0);
      expect(heights[1], 200.0); // max volume gets maxChartHeight
    });

    test('bar heights are proportional to volumes', () {
      final heights = computeBarHeights([50, 100, 75, 25], 200.0);
      expect(heights[0], 100.0); // 50/100 * 200
      expect(heights[1], 200.0); // 100/100 * 200
      expect(heights[2], 150.0); // 75/100 * 200
      expect(heights[3], 50.0);  // 25/100 * 200
    });

    test('single non-zero volume gets full height', () {
      final heights = computeBarHeights([0, 0, 42, 0], 180.0);
      expect(heights[2], 180.0);
      expect(heights[0], 0.0);
      expect(heights[1], 0.0);
      expect(heights[3], 0.0);
    });
  });
}
