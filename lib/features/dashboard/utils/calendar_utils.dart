/// Calendar grid generation and day status utilities for the Dashboard.
///
/// Used by [CalendarGridWidget] to render the monthly calendar with
/// workout completion indicators.
library;

/// Status classification for a single calendar day cell.
enum DayStatus {
  /// At least one WorkoutSession was completed on this date.
  completed,

  /// Today's date with no completed workout session.
  today,

  /// Any other date with no special status.
  normal,
}

/// Generates a flat list representing the calendar grid for [year]/[month].
///
/// Returns a list of `int?` values where:
/// - `null` represents an empty leading cell (days before the 1st)
/// - An integer (1–31) represents an actual day of the month
///
/// The grid assumes weeks start on Monday (weekday index 1).
/// Leading empty cells = `firstDayOfMonth.weekday - 1`.
List<int?> generateCalendarGrid(int year, int month) {
  final firstDay = DateTime(year, month, 1);
  final daysInMonth = DateTime(year, month + 1, 0).day;

  // Monday = 1, so leading empties = weekday - 1
  final leadingEmpties = firstDay.weekday - 1;

  final grid = <int?>[];

  // Add leading null cells
  for (var i = 0; i < leadingEmpties; i++) {
    grid.add(null);
  }

  // Add day numbers
  for (var day = 1; day <= daysInMonth; day++) {
    grid.add(day);
  }

  return grid;
}

/// Determines the [DayStatus] for a given [date].
///
/// Compares by year, month, and day only (time component is ignored).
///
/// - Returns [DayStatus.completed] if [date] exists in [completedDates].
/// - Returns [DayStatus.today] if [date] matches today and is NOT in [completedDates].
/// - Returns [DayStatus.normal] otherwise.
DayStatus getDayStatus(DateTime date, Set<DateTime> completedDates) {
  final dateOnly = DateTime(date.year, date.month, date.day);

  // Check if this date is in the completed set (compare date-only)
  final isCompleted = completedDates.any(
    (d) => d.year == dateOnly.year && d.month == dateOnly.month && d.day == dateOnly.day,
  );

  if (isCompleted) {
    return DayStatus.completed;
  }

  final now = DateTime.now();
  final todayOnly = DateTime(now.year, now.month, now.day);

  if (dateOnly == todayOnly) {
    return DayStatus.today;
  }

  return DayStatus.normal;
}
