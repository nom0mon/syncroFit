import 'package:synchrofit/core/models/workout_history.dart';

class WeekRange {
  final DateTime start;
  final DateTime end;

  const WeekRange({required this.start, required this.end});
}

/// A single data point for the weekly-completion chart.
///
/// [label]  — display label for the X-axis, e.g. "Oct 28".
/// [count]  — number of workouts completed during this week (0 for missed weeks).
/// [range]  — the Monday-anchored calendar week this point represents.
class WeeklyDataPoint {
  final String label;
  final int count;
  final WeekRange range;

  const WeeklyDataPoint({
    required this.label,
    required this.count,
    required this.range,
  });
}

// Short month names used by [_formatWeekLabel] — avoids an `intl` dependency.
const _kMonthAbbr = [
  '', // 1-indexed; index 0 unused
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Returns a short "Mmm D" label for a week starting on [date], e.g. "Oct 28".
String _formatWeekLabel(DateTime date) =>
    '${_kMonthAbbr[date.month]} ${date.day}';

/// Builds a continuous, left-to-right chronological list of [WeeklyDataPoint]s
/// covering the last [weekCount] complete ISO (Monday-anchored) weeks ending
/// with the current week.
///
/// Weeks with no completed workouts are zero-filled so the timeline has no
/// gaps, accurately reflecting missed training periods.
///
/// The returned list is sorted oldest → newest (index 0 = oldest).
List<WeeklyDataPoint> buildWeeklyCompletionData({
  required List<WorkoutHistory> sessions,
  required DateTime referenceDate,
  int weekCount = 6,
}) {
  // Normalise to midnight local time to avoid DST edge cases.
  final today = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  );

  // Find the Monday of the current week (ISO weekday: Mon=1, Sun=7).
  final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));

  final points = <WeeklyDataPoint>[];

  for (var i = weekCount - 1; i >= 0; i--) {
    final weekStart = currentWeekStart.subtract(Duration(days: 7 * i));
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
      23,
      59,
      59,
    );
    final range = WeekRange(start: weekStart, end: weekEnd);

    final count = sessions
        .where(
          (s) => isInRange(s.effectiveCompletedAt, range),
        )
        .length;

    points.add(WeeklyDataPoint(
      label: _formatWeekLabel(weekStart),
      count: count,
      range: range,
    ));
  }

  return points; // already oldest → newest
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
