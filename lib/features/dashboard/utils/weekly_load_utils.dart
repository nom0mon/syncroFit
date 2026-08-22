import 'package:synchrofit/core/models/workout_history.dart';

/// A pair representing the start and end of a week range.
/// [start] is Monday 00:00:00, [end] is Sunday 23:59:59.
class WeekRange {
  final DateTime start;
  final DateTime end;

  const WeekRange({required this.start, required this.end});
}

/// Computes four consecutive week ranges (Mon–Sun) covering the last 4 weeks
/// relative to [referenceDate].
///
/// W1 is the oldest week, W4 is the most recent.
/// W4's Sunday is the Sunday of or before the reference date's week.
List<WeekRange> computeWeekRanges(DateTime referenceDate) {
  // Normalize to date-only (strip time)
  final ref = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);

  // Find the Sunday of or before the reference date's week.
  // DateTime.weekday: Monday=1 ... Sunday=7
  final int daysUntilSunday = DateTime.sunday - ref.weekday;
  final DateTime w4Sunday;
  if (daysUntilSunday >= 0) {
    // ref is Mon-Sun of current week; Sunday of this week
    w4Sunday = ref.add(Duration(days: daysUntilSunday));
  } else {
    // This shouldn't happen since Sunday=7 is max weekday, but guard anyway
    w4Sunday = ref.add(Duration(days: daysUntilSunday + 7));
  }

  // W4 Monday is 6 days before W4 Sunday
  final DateTime w4Monday = w4Sunday.subtract(const Duration(days: 6));

  // Build 4 week ranges going backwards
  final List<WeekRange> ranges = [];
  for (int i = 3; i >= 0; i--) {
    final weekStart = w4Monday.subtract(Duration(days: i * 7));
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
      23,
      59,
      59,
    );
    ranges.add(WeekRange(start: weekStart, end: weekEnd));
  }

  return ranges;
}

/// Returns true if [date] falls within the week starting at [weekStart]
/// (Monday 00:00:00) through Sunday 23:59:59.
bool isInWeek(DateTime date, DateTime weekStart) {
  final weekEnd = DateTime(
    weekStart.year,
    weekStart.month,
    weekStart.day + 6,
    23,
    59,
    59,
  );
  return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
}

/// Calculates the total training volume for a given week.
///
/// Volume = sum of total reps (setsCompleted × reps) for all rep-based
/// exercises in sessions where completedAt falls within the week starting at
/// [weekStart]. Timed exercises (e.g. Plank) contribute 0 so their duration
/// in seconds does not inflate the rep-based total.
int calculateWeeklyVolume(List<WorkoutHistory> sessions, DateTime weekStart) {
  return sessions
      .where((s) => isInWeek(s.completedAt, weekStart))
      .expand((s) => s.exercises)
      .fold(0, (sum, e) => sum + e.repVolume);
}

/// Computes proportional bar heights for a list of volumes given a maximum
/// chart height.
///
/// If the max volume > 0, each height is `(volume / maxVolume) * maxChartHeight`.
/// If all volumes are 0, all bars get a uniform minimum height of 4.0.
List<double> computeBarHeights(List<int> volumes, double maxChartHeight) {
  if (volumes.isEmpty) return [];

  final int maxVolume = volumes.reduce((a, b) => a > b ? a : b);

  if (maxVolume == 0) {
    return List.filled(volumes.length, 4.0);
  }

  return volumes
      .map((v) => (v / maxVolume) * maxChartHeight)
      .toList();
}
