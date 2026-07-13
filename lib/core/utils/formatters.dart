/// Date, time, and relative timestamp formatting utilities.
///
/// Used by Community Feed, Notifications, and Workout modules
/// for displaying human-readable timestamps and durations.
library;

/// Returns a relative timestamp string such as "just now", "2 min ago",
/// "1 hour ago", "3 days ago", "1 week ago", etc.
///
/// The [dateTime] is compared against [DateTime.now()] (or the optional [now]
/// parameter for testability).
String formatRelativeTimestamp(DateTime dateTime, {DateTime? now}) {
  final currentTime = now ?? DateTime.now();
  final difference = currentTime.difference(dateTime);

  if (difference.isNegative) {
    return 'just now';
  }

  final seconds = difference.inSeconds;
  final minutes = difference.inMinutes;
  final hours = difference.inHours;
  final days = difference.inDays;

  if (seconds < 60) {
    return 'just now';
  } else if (minutes < 60) {
    return minutes == 1 ? '1 min ago' : '$minutes min ago';
  } else if (hours < 24) {
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  } else if (days < 7) {
    return days == 1 ? '1 day ago' : '$days days ago';
  } else if (days < 30) {
    final weeks = days ~/ 7;
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  } else if (days < 365) {
    final months = days ~/ 30;
    return months == 1 ? '1 month ago' : '$months months ago';
  } else {
    final years = days ~/ 365;
    return years == 1 ? '1 year ago' : '$years years ago';
  }
}

/// Formats a duration given in [totalSeconds] into "mm:ss" format.
///
/// Examples:
/// - 90 seconds → "01:30"
/// - 0 seconds → "00:00"
/// - 3661 seconds → "61:01"
String formatDuration(int totalSeconds) {
  if (totalSeconds < 0) {
    totalSeconds = 0;
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final minutesStr = minutes.toString().padLeft(2, '0');
  final secondsStr = seconds.toString().padLeft(2, '0');
  return '$minutesStr:$secondsStr';
}

/// Formats a [DateTime] into a human-readable date string like "Jan 15, 2024".
String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  return '$month ${date.day}, ${date.year}';
}
