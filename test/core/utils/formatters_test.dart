import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/utils/formatters.dart';

void main() {
  group('formatRelativeTimestamp', () {
    final now = DateTime(2024, 6, 15, 12, 0, 0);

    test('returns "just now" for less than 60 seconds ago', () {
      final dateTime = now.subtract(const Duration(seconds: 30));
      expect(formatRelativeTimestamp(dateTime, now: now), 'just now');
    });

    test('returns "just now" for 0 seconds ago', () {
      expect(formatRelativeTimestamp(now, now: now), 'just now');
    });

    test('returns "just now" for future timestamps', () {
      final future = now.add(const Duration(minutes: 5));
      expect(formatRelativeTimestamp(future, now: now), 'just now');
    });

    test('returns "1 min ago" for exactly 1 minute', () {
      final dateTime = now.subtract(const Duration(minutes: 1));
      expect(formatRelativeTimestamp(dateTime, now: now), '1 min ago');
    });

    test('returns "X min ago" for 2-59 minutes', () {
      final dateTime = now.subtract(const Duration(minutes: 45));
      expect(formatRelativeTimestamp(dateTime, now: now), '45 min ago');
    });

    test('returns "1 hour ago" for exactly 1 hour', () {
      final dateTime = now.subtract(const Duration(hours: 1));
      expect(formatRelativeTimestamp(dateTime, now: now), '1 hour ago');
    });

    test('returns "X hours ago" for 2-23 hours', () {
      final dateTime = now.subtract(const Duration(hours: 5));
      expect(formatRelativeTimestamp(dateTime, now: now), '5 hours ago');
    });

    test('returns "1 day ago" for exactly 1 day', () {
      final dateTime = now.subtract(const Duration(days: 1));
      expect(formatRelativeTimestamp(dateTime, now: now), '1 day ago');
    });

    test('returns "X days ago" for 2-6 days', () {
      final dateTime = now.subtract(const Duration(days: 3));
      expect(formatRelativeTimestamp(dateTime, now: now), '3 days ago');
    });

    test('returns "1 week ago" for 7 days', () {
      final dateTime = now.subtract(const Duration(days: 7));
      expect(formatRelativeTimestamp(dateTime, now: now), '1 week ago');
    });

    test('returns "X weeks ago" for 14-27 days', () {
      final dateTime = now.subtract(const Duration(days: 21));
      expect(formatRelativeTimestamp(dateTime, now: now), '3 weeks ago');
    });

    test('returns "1 month ago" for 30 days', () {
      final dateTime = now.subtract(const Duration(days: 30));
      expect(formatRelativeTimestamp(dateTime, now: now), '1 month ago');
    });

    test('returns "X months ago" for 60-364 days', () {
      final dateTime = now.subtract(const Duration(days: 90));
      expect(formatRelativeTimestamp(dateTime, now: now), '3 months ago');
    });

    test('returns "1 year ago" for 365 days', () {
      final dateTime = now.subtract(const Duration(days: 365));
      expect(formatRelativeTimestamp(dateTime, now: now), '1 year ago');
    });

    test('returns "X years ago" for 730+ days', () {
      final dateTime = now.subtract(const Duration(days: 730));
      expect(formatRelativeTimestamp(dateTime, now: now), '2 years ago');
    });
  });

  group('formatDuration', () {
    test('formats 0 seconds as "00:00"', () {
      expect(formatDuration(0), '00:00');
    });

    test('formats single-digit seconds with leading zero', () {
      expect(formatDuration(5), '00:05');
    });

    test('formats 60 seconds as "01:00"', () {
      expect(formatDuration(60), '01:00');
    });

    test('formats 90 seconds as "01:30"', () {
      expect(formatDuration(90), '01:30');
    });

    test('formats large values correctly', () {
      expect(formatDuration(3661), '61:01');
    });

    test('handles negative values as 00:00', () {
      expect(formatDuration(-10), '00:00');
    });
  });

  group('formatDate', () {
    test('formats date as "Mon DD, YYYY"', () {
      final date = DateTime(2024, 1, 15);
      expect(formatDate(date), 'Jan 15, 2024');
    });

    test('formats month correctly for all months', () {
      expect(formatDate(DateTime(2024, 1, 1)), 'Jan 1, 2024');
      expect(formatDate(DateTime(2024, 2, 14)), 'Feb 14, 2024');
      expect(formatDate(DateTime(2024, 3, 20)), 'Mar 20, 2024');
      expect(formatDate(DateTime(2024, 4, 5)), 'Apr 5, 2024');
      expect(formatDate(DateTime(2024, 5, 31)), 'May 31, 2024');
      expect(formatDate(DateTime(2024, 6, 10)), 'Jun 10, 2024');
      expect(formatDate(DateTime(2024, 7, 4)), 'Jul 4, 2024');
      expect(formatDate(DateTime(2024, 8, 22)), 'Aug 22, 2024');
      expect(formatDate(DateTime(2024, 9, 9)), 'Sep 9, 2024');
      expect(formatDate(DateTime(2024, 10, 31)), 'Oct 31, 2024');
      expect(formatDate(DateTime(2024, 11, 28)), 'Nov 28, 2024');
      expect(formatDate(DateTime(2024, 12, 25)), 'Dec 25, 2024');
    });

    test('handles single-digit days without leading zero', () {
      final date = DateTime(2024, 3, 1);
      expect(formatDate(date), 'Mar 1, 2024');
    });
  });
}
