import 'package:glados/glados.dart';
import 'package:synchrofit/features/dashboard/utils/weekly_load_utils.dart';
import 'package:synchrofit/shared/models/completed_exercise.dart';
import 'package:synchrofit/core/models/workout_history.dart';

void main() {
  group(
      'Property 4: Four-week ranges are non-overlapping and chronologically ordered',
      () {
    /// **Validates: Requirements 5.2**
    ///
    /// For any reference date, the computed four week ranges SHALL each span
    /// exactly 7 days (Monday 00:00 to Sunday 23:59), be non-overlapping, be in
    /// strictly ascending chronological order (W1 oldest, W4 most recent), and
    /// the union of all four ranges SHALL cover exactly 28 consecutive days
    /// ending on the Sunday of or before the reference date's week.

    Glados2(any.intInRange(2000, 2101), any.intInRange(1, 366)).test(
      'computeWeekRanges returns exactly 4 ranges for any reference date',
      (year, dayOfYear) {
        final referenceDate =
            DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
        final ranges = computeWeekRanges(referenceDate);
        expect(ranges.length, 4);
      },
    );

    Glados2(any.intInRange(2000, 2101), any.intInRange(1, 366)).test(
      'each range spans exactly 7 days (Monday 00:00 to Sunday 23:59)',
      (year, dayOfYear) {
        final referenceDate =
            DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
        final ranges = computeWeekRanges(referenceDate);

        for (final range in ranges) {
          // Start is Monday
          expect(range.start.weekday, DateTime.monday,
              reason: 'Range start should be Monday');
          // End is Sunday
          expect(range.end.weekday, DateTime.sunday,
              reason: 'Range end should be Sunday');
          // Start is at 00:00:00
          expect(range.start.hour, 0);
          expect(range.start.minute, 0);
          expect(range.start.second, 0);
          // End is at 23:59:59
          expect(range.end.hour, 23);
          expect(range.end.minute, 59);
          expect(range.end.second, 59);
          // Span is exactly 6 days apart (Mon to Sun = 7 days inclusive)
          final daysDifference = range.end.difference(range.start).inDays;
          expect(daysDifference, 6,
              reason: 'Range should span 6 days (Mon to Sun)');
        }
      },
    );

    Glados2(any.intInRange(2000, 2101), any.intInRange(1, 366)).test(
      'ranges are non-overlapping and chronologically ordered',
      (year, dayOfYear) {
        final referenceDate =
            DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
        final ranges = computeWeekRanges(referenceDate);

        for (int i = 0; i < 3; i++) {
          // W(i) end is before W(i+1) start — non-overlapping
          expect(ranges[i].end.isBefore(ranges[i + 1].start), isTrue,
              reason: 'Range $i end should be before range ${i + 1} start');
          // Chronological order
          expect(ranges[i].start.isBefore(ranges[i + 1].start), isTrue,
              reason: 'Range $i start should be before range ${i + 1} start');
        }
      },
    );

    Glados2(any.intInRange(2000, 2101), any.intInRange(1, 366)).test(
      'all 4 ranges cover exactly 28 consecutive days',
      (year, dayOfYear) {
        final referenceDate =
            DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
        final ranges = computeWeekRanges(referenceDate);

        // The total span from W1 Monday to W4 Sunday should be 27 days (28 days inclusive)
        final totalDays = ranges[3].end.difference(ranges[0].start).inDays;
        expect(totalDays, 27,
            reason:
                'Total span should be 27 days (28 consecutive days inclusive)');

        // Each consecutive range should be exactly 7 days apart (start to start)
        for (int i = 0; i < 3; i++) {
          final daysBetweenStarts =
              ranges[i + 1].start.difference(ranges[i].start).inDays;
          expect(daysBetweenStarts, 7,
              reason: 'Consecutive ranges should be 7 days apart');
        }
      },
    );
  });

  group('Property 5: Weekly volume calculation equals sum of sets times reps',
      () {
    /// **Validates: Requirements 5.3**
    ///
    /// For any list of CompletedExercise items (including empty lists), the
    /// calculated weekly volume SHALL equal the sum of (setsCompleted ×
    /// repsOrDuration) for each item, and SHALL be a non-negative integer.

    Glados(any.listWithLengthInRange(0, 11, any.intInRange(0, 100))).test(
      'weekly volume equals manual sum of sets * reps for exercises in a session',
      (exerciseData) {
        final weekStart = DateTime(2025, 1, 13); // Monday
        final sessionDate =
            DateTime(2025, 1, 15); // Wednesday - within the week

        final exercises = exerciseData.asMap().entries.map((entry) {
          final setsCompleted = (entry.value % 10) + 1; // 1-10 sets
          final repsOrDuration = (entry.value ~/ 10) + 1; // 1-10 reps
          return CompletedExercise(
            exerciseId: 'e${entry.key}',
            exerciseName: 'Exercise ${entry.key}',
            setsCompleted: setsCompleted,
            repsOrDuration: repsOrDuration,
          );
        }).toList();

        final sessions = exercises.isEmpty
            ? <WorkoutHistory>[]
            : [
                WorkoutHistory(
                  id: 'session1',
                  userId: 'u1',
                  workoutName: 'Test Workout',
                  completedAt: sessionDate,
                  totalDurationSeconds: 3600,
                  exercisesCompleted: exercises.map((e) => e.toJson()).toList(),
                ),
              ];

        final volume = calculateWeeklyVolume(sessions, weekStart);

        // Manual calculation
        final expectedVolume = exercises.fold<int>(
          0,
          (sum, e) => sum + e.setsCompleted * e.repsOrDuration,
        );

        expect(volume, expectedVolume);
        expect(volume, greaterThanOrEqualTo(0));
      },
    );

    Glados2(
      any.listWithLengthInRange(1, 6, any.intInRange(1, 20)),
      any.listWithLengthInRange(1, 6, any.intInRange(1, 50)),
    ).test(
      'volume is always non-negative for any sets and reps values',
      (setsList, repsList) {
        final weekStart = DateTime(2025, 1, 13);
        final sessionDate = DateTime(2025, 1, 14);

        // Use the shorter list length to pair sets and reps
        final count = setsList.length < repsList.length
            ? setsList.length
            : repsList.length;

        final exercises = List.generate(count, (i) {
          return CompletedExercise(
            exerciseId: 'e$i',
            exerciseName: 'Exercise $i',
            setsCompleted: setsList[i],
            repsOrDuration: repsList[i],
          );
        });

        final sessions = [
          WorkoutHistory(
            id: 'session1',
            userId: 'u1',
            workoutName: 'Test Workout',
            completedAt: sessionDate,
            totalDurationSeconds: 3600,
            exercisesCompleted: exercises.map((e) => e.toJson()).toList(),
          ),
        ];

        final volume = calculateWeeklyVolume(sessions, weekStart);
        expect(volume, greaterThanOrEqualTo(0));

        // Verify it equals the manual sum
        final manualSum = exercises.fold<int>(
          0,
          (sum, e) => sum + e.setsCompleted * e.repsOrDuration,
        );
        expect(volume, manualSum);
      },
    );
  });

  group('Property 6: Bar height scaling is proportional to maximum volume', () {
    /// **Validates: Requirements 5.6, 5.7**
    ///
    /// For any four non-negative integer volume values where at least one is
    /// greater than zero, the computed bar height for each week SHALL satisfy:
    /// height[i] / maxChartHeight == volume[i] / maxVolume (within floating-point
    /// tolerance). When all four volumes are zero, all bar heights SHALL be
    /// equal to a defined minimum height (4.0).

    Glados(any.listWithLength(4, any.intInRange(0, 10000))).test(
      'bar heights are proportional to maximum volume when at least one > 0',
      (volumes) {
        final maxVolume = volumes.reduce((a, b) => a > b ? a : b);
        const maxChartHeight = 200.0;

        final heights = computeBarHeights(volumes, maxChartHeight);

        expect(heights.length, 4);

        if (maxVolume == 0) {
          // All zero: all bars get minimum height
          for (final height in heights) {
            expect(height, 4.0,
                reason: 'All-zero volumes should produce minimum height 4.0');
          }
        } else {
          // At least one > 0: heights are proportional
          for (int i = 0; i < 4; i++) {
            final expectedHeight = (volumes[i] / maxVolume) * maxChartHeight;
            expect(heights[i], closeTo(expectedHeight, 1e-10),
                reason:
                    'Height for volume ${volumes[i]} should be proportional: '
                    'expected $expectedHeight but got ${heights[i]}');
          }

          // The max volume bar should get full chart height
          final maxIndex = volumes.indexOf(maxVolume);
          expect(heights[maxIndex], closeTo(maxChartHeight, 1e-10),
              reason: 'Maximum volume bar should get full chart height');
        }
      },
    );

    Glados(any.listWithLength(4, any.intInRange(1, 10000))).test(
      'all bar heights are between 0 and maxChartHeight (non-zero volumes)',
      (volumes) {
        const maxChartHeight = 200.0;
        final heights = computeBarHeights(volumes, maxChartHeight);

        for (int i = 0; i < 4; i++) {
          expect(heights[i], greaterThanOrEqualTo(0.0),
              reason: 'Bar height should be non-negative');
          expect(heights[i], lessThanOrEqualTo(maxChartHeight),
              reason: 'Bar height should not exceed max chart height');
        }
      },
    );

    test('all zero volumes produce minimum height of 4.0', () {
      final heights = computeBarHeights([0, 0, 0, 0], 200.0);
      expect(heights, [4.0, 4.0, 4.0, 4.0]);
    });
  });
}
