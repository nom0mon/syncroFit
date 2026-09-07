import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/dashboard/utils/calendar_utils.dart';

void main() {
  group('generateCalendarGrid', () {
    test('January 2024 starts on Monday — no leading empties', () {
      // Jan 1, 2024 is a Monday
      final grid = generateCalendarGrid(2024, 1);
      expect(grid.first, 1); // no leading nulls
      expect(grid.length, 31); // 31 days, no empties
      expect(grid.last, 31);
    });

    test('February 2024 (leap year) starts on Thursday — 3 leading empties',
        () {
      // Feb 1, 2024 is a Thursday (weekday = 4), leading empties = 3
      final grid = generateCalendarGrid(2024, 2);
      expect(grid.where((d) => d == null).length, 3);
      expect(grid.where((d) => d != null).length, 29); // leap year
      expect(grid.length, 32); // 3 empties + 29 days
    });

    test('February 2023 (non-leap year) has 28 days', () {
      final grid = generateCalendarGrid(2023, 2);
      final dayCount = grid.where((d) => d != null).length;
      expect(dayCount, 28);
    });

    test('September 2023 starts on Friday — 4 leading empties', () {
      // Sep 1, 2023 is a Friday (weekday = 5), leading empties = 4
      final grid = generateCalendarGrid(2023, 9);
      expect(grid.where((d) => d == null).length, 4);
      expect(grid.where((d) => d != null).length, 30);
      expect(grid[4], 1); // first day at index 4
    });

    test('day numbers are sequential from 1 to daysInMonth', () {
      final grid = generateCalendarGrid(2024, 3); // March 2024
      final days = grid.whereType<int>().toList();
      for (var i = 0; i < days.length; i++) {
        expect(days[i], i + 1);
      }
    });

    test('all cells are either null or valid day numbers', () {
      final grid = generateCalendarGrid(2024, 7); // July 2024
      for (final cell in grid) {
        if (cell != null) {
          expect(cell, greaterThanOrEqualTo(1));
          expect(cell, lessThanOrEqualTo(31));
        }
      }
    });
  });

  group('getDayStatus', () {
    test('returns completed when date is in completedDates', () {
      final date = DateTime(2024, 3, 15);
      final completed = {DateTime(2024, 3, 15)};
      expect(getDayStatus(date, completed), DayStatus.completed);
    });

    test('returns completed even if date has time component', () {
      final date = DateTime(2024, 3, 15, 14, 30);
      final completed = {DateTime(2024, 3, 15)};
      expect(getDayStatus(date, completed), DayStatus.completed);
    });

    test('returns today when date is today and not completed', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final completed = <DateTime>{};
      expect(getDayStatus(today, completed), DayStatus.today);
    });

    test('returns completed over today when today is in completedDates', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final completed = {today};
      expect(getDayStatus(today, completed), DayStatus.completed);
    });

    test('returns normal for a past date not in completedDates', () {
      final date = DateTime(2020, 1, 1);
      final completed = <DateTime>{};
      expect(getDayStatus(date, completed), DayStatus.normal);
    });

    test('returns normal for a future date not in completedDates', () {
      final date = DateTime(2099, 12, 31);
      final completed = <DateTime>{};
      expect(getDayStatus(date, completed), DayStatus.normal);
    });

    test('ignores time component in completedDates', () {
      final date = DateTime(2024, 5, 10);
      final completed = {DateTime(2024, 5, 10, 23, 59, 59)};
      expect(getDayStatus(date, completed), DayStatus.completed);
    });
  });
}
