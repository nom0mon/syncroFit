import 'package:glados/glados.dart';
import 'package:synchrofit/features/dashboard/utils/session_display_utils.dart';

void main() {
  group('formatDateDisplay', () {
    test('formats a typical date correctly', () {
      final date = DateTime(2026, 4, 25);
      expect(formatDateDisplay(date), 'April 25, 2026');
    });

    test('formats January 1st correctly', () {
      final date = DateTime(2024, 1, 1);
      expect(formatDateDisplay(date), 'January 1, 2024');
    });

    test('formats December 31st correctly', () {
      final date = DateTime(2023, 12, 31);
      expect(formatDateDisplay(date), 'December 31, 2023');
    });

    test('does not pad single-digit days with leading zeros', () {
      final date = DateTime(2025, 3, 5);
      expect(formatDateDisplay(date), 'March 5, 2025');
    });

    test('formats February 29 in a leap year', () {
      final date = DateTime(2024, 2, 29);
      expect(formatDateDisplay(date), 'February 29, 2024');
    });
  });

  group('formatDuration', () {
    test('formats 0 seconds as "0 min"', () {
      expect(formatDuration(0), '0 min');
    });

    test('formats 60 seconds as "1 min"', () {
      expect(formatDuration(60), '1 min');
    });

    test('formats 2700 seconds (45 min) correctly', () {
      expect(formatDuration(2700), '45 min');
    });

    test('rounds 90 seconds to "2 min" (rounds up from 1.5)', () {
      expect(formatDuration(90), '2 min');
    });

    test('rounds 89 seconds to "1 min" (rounds down from ~1.48)', () {
      expect(formatDuration(89), '1 min');
    });

    test('rounds 29 seconds to "0 min"', () {
      expect(formatDuration(29), '0 min');
    });

    test('rounds 30 seconds to "1 min" (rounds up from 0.5)', () {
      expect(formatDuration(30), '1 min');
    });
  });

  group('Property 7: Date display formatting round-trip', () {
    /// **Validates: Requirements 6.2**
    ///
    /// For any valid DateTime (year 2000–2100, months 1–12, valid day for that
    /// month), the formatted display string SHALL match the pattern
    /// "{FullMonthName} {Day}, {Year}" where FullMonthName is the English month
    /// name, Day is the day number without leading zeros, and Year is the
    /// 4-digit year.

    const monthNames = [
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

    Glados2(any.intInRange(2000, 2101), any.intInRange(1, 13)).test(
      'formatted date matches "Month Day, Year" pattern for any valid year/month',
      (year, month) {
        // Pick a valid day (day 1 is always valid)
        final date = DateTime(year, month, 1);
        final result = formatDateDisplay(date);

        expect(result, '${monthNames[month - 1]} ${date.day}, $year');
      },
    );

    Glados(any.intInRange(2000, 2101)).test(
      'day portion never has leading zeros',
      (year) {
        // Test days 1-9 which could potentially have leading zeros
        for (int day = 1; day <= 9; day++) {
          final date = DateTime(year, 1, day);
          final result = formatDateDisplay(date);
          // Pattern: Month Day, Year — day should be single digit without padding
          final dayPart = result.split(' ')[1].replaceAll(',', '');
          expect(dayPart, '$day');
        }
      },
    );
  });

  group('Property 8: Duration formatting correctness', () {
    /// **Validates: Requirements 6.4**
    ///
    /// For any non-negative integer representing total seconds, the formatted
    /// duration string SHALL equal "{n} min" where n equals (totalSeconds / 60)
    /// rounded to the nearest integer, with n being at least 0.

    Glados(any.intInRange(0, 100000)).test(
      'duration equals rounded (totalSeconds / 60) min for any non-negative seconds',
      (totalSeconds) {
        final result = formatDuration(totalSeconds);
        final expectedMinutes = (totalSeconds / 60).round();
        expect(result, '$expectedMinutes min');
      },
    );

    Glados(any.intInRange(0, 100000)).test(
      'duration result is always non-negative',
      (totalSeconds) {
        final result = formatDuration(totalSeconds);
        final numericPart = int.parse(result.split(' ').first);
        expect(numericPart, greaterThanOrEqualTo(0));
      },
    );
  });
}
