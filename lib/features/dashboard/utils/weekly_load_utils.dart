import 'package:synchrofit/core/models/workout_history.dart';

class WeekRange {
  final DateTime start;
  final DateTime end;

  const WeekRange({required this.start, required this.end});
}

/// Splits the reference month into stable buckets: days 1-7, 8-14, 15-21,
/// 22-28, and (when present) 29 through the end of the month.
List<WeekRange> computeWeekRanges(DateTime referenceDate) {
  final lastDay = DateTime(referenceDate.year, referenceDate.month + 1, 0).day;
  final ranges = <WeekRange>[];
  for (var day = 1; day <= lastDay; day += 7) {
    final endDay = (day + 6).clamp(1, lastDay);
    ranges.add(WeekRange(
      start: DateTime(referenceDate.year, referenceDate.month, day),
      end: DateTime(
        referenceDate.year,
        referenceDate.month,
        endDay,
        23,
        59,
        59,
      ),
    ));
  }
  return ranges;
}

bool isInRange(DateTime date, WeekRange range) {
  final localDate = date.toLocal();
  return !localDate.isBefore(range.start) && !localDate.isAfter(range.end);
}

/// Backward-compatible seven-day range helper used by existing callers.
bool isInWeek(DateTime date, DateTime weekStart) => isInRange(
      date,
      WeekRange(
        start: weekStart,
        end: DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + 6,
          23,
          59,
          59,
        ),
      ),
    );

int calculateWeeklyVolume(List<WorkoutHistory> sessions, DateTime weekStart) {
  return sessions
      .where((session) => isInWeek(session.effectiveCompletedAt, weekStart))
      .expand((session) => session.exercises)
      .fold(0, (sum, exercise) => sum + exercise.repVolume);
}

int calculateVolumeInRange(
  List<WorkoutHistory> sessions,
  WeekRange range,
) {
  return sessions
      .where((session) => isInRange(session.effectiveCompletedAt, range))
      .expand((session) => session.exercises)
      .fold(0, (sum, exercise) => sum + exercise.repVolume);
}

List<double> computeBarHeights(List<int> volumes, double maxChartHeight) {
  if (volumes.isEmpty) return [];
  final maxVolume = volumes.reduce((a, b) => a > b ? a : b);
  if (maxVolume == 0) return List.filled(volumes.length, 4.0);
  return volumes.map((value) => (value / maxVolume) * maxChartHeight).toList();
}
