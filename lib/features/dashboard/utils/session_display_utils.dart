/// Utility functions for formatting dates and session durations
/// on the Dashboard's Completed Sessions section.
library;

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats a [date] as "Month Day, Year" (e.g. "April 25, 2026").
///
/// Day is rendered without leading zeros. Month is the full English name.
/// Year is the 4-digit year.
String formatDateDisplay(DateTime date) {
  final month = _monthNames[date.month - 1];
  return '$month ${date.day}, ${date.year}';
}

/// Formats [totalSeconds] as "{n} min" where n is the number of seconds
/// divided by 60, rounded to the nearest integer. The result is at least 0.
String formatDuration(int totalSeconds) {
  final minutes = (totalSeconds / 60).round().clamp(0, double.infinity).toInt();
  return '$minutes min';
}
