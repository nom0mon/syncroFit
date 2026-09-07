import 'package:glados/glados.dart';
import 'package:synchrofit/features/dashboard/utils/calendar_utils.dart';

/// **Validates: Requirements 4.3, 4.4, 4.5, 4.6**
///
/// Property 2: Calendar grid contains correct day count for any month
///
/// For any valid year (2000–2100) and month (1–12), the calendar grid
/// generation function SHALL produce exactly N day cells where N equals
/// the number of days in that month, plus empty leading cells equal to
/// (firstDayOfMonth.weekday - 1) when Monday=1, and non-null cells are
/// sequential from 1 to daysInMonth.
///
/// Property 3: Day status classification is exhaustive and correct
///
/// For any date and any set of completed dates, the day status function
/// SHALL return `completed` if and only if the date exists in the completed
/// set, `today` if and only if the date equals today's date and is not in
/// the completed set, and `normal` in all other cases — with exactly one
/// status assigned per date.
void main() {
  group('Property 2: Calendar grid contains correct day count for any month',
      () {
    Glados2(any.intInRange(2000, 2101), any.intInRange(1, 13)).test(
      'non-null cell count equals days in month for any year/month',
      (year, month) {
        final grid = generateCalendarGrid(year, month);
        final daysInMonth = DateTime(year, month + 1, 0).day;

        final nonNullCells = grid.where((cell) => cell != null).length;
        expect(
          nonNullCells,
          equals(daysInMonth),
          reason:
              'Expected $daysInMonth day cells for $year-$month, got $nonNullCells',
        );
      },
    );

    Glados2(any.intInRange(2000, 2101), any.intInRange(1, 13)).test(
      'null cell count equals (firstDayOfMonth.weekday - 1)',
      (year, month) {
        final grid = generateCalendarGrid(year, month);
        final firstDay = DateTime(year, month, 1);
        final expectedLeadingEmpties = firstDay.weekday - 1;

        final nullCells = grid.where((cell) => cell == null).length;
        expect(
          nullCells,
          equals(expectedLeadingEmpties),
          reason:
              'Expected $expectedLeadingEmpties leading empties for $year-$month '
              '(weekday=${firstDay.weekday}), got $nullCells',
        );
      },
    );

    Glados2(any.intInRange(2000, 2101), any.intInRange(1, 13)).test(
      'non-null cells are sequential from 1 to daysInMonth',
      (year, month) {
        final grid = generateCalendarGrid(year, month);
        final daysInMonth = DateTime(year, month + 1, 0).day;

        final days = grid.whereType<int>().toList();
        expect(days.length, equals(daysInMonth));

        for (var i = 0; i < days.length; i++) {
          expect(
            days[i],
            equals(i + 1),
            reason: 'Day at index $i should be ${i + 1}, got ${days[i]} '
                'for $year-$month',
          );
        }
      },
    );
  });

  group('Property 3: Day status classification is exhaustive and correct', () {
    Glados2(
      any.intInRange(2000, 2101),
      any.intInRange(1, 366),
    ).test(
      'completed dates return DayStatus.completed',
      (year, dayOfYear) {
        // Generate a date from year + dayOfYear
        final date = DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
        // Ensure date is still within the year (handle overflow gracefully)
        final completedDates = {DateTime(date.year, date.month, date.day)};

        final status = getDayStatus(date, completedDates);
        expect(
          status,
          equals(DayStatus.completed),
          reason: 'Date $date is in completedDates, should return completed',
        );
      },
    );

    Glados2(
      any.intInRange(2000, 2101),
      any.intInRange(1, 366),
    ).test(
      'non-completed non-today dates return DayStatus.normal',
      (year, dayOfYear) {
        final date = DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
        final dateOnly = DateTime(date.year, date.month, date.day);

        // Use an empty completed set
        final completedDates = <DateTime>{};

        final now = DateTime.now();
        final todayOnly = DateTime(now.year, now.month, now.day);

        // Skip if the generated date happens to be today
        if (dateOnly == todayOnly) return;

        final status = getDayStatus(date, completedDates);
        expect(
          status,
          equals(DayStatus.normal),
          reason:
              'Date $dateOnly is not completed and not today, should return normal',
        );
      },
    );

    test('today with no completed workout returns DayStatus.today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final completedDates = <DateTime>{};

      final status = getDayStatus(today, completedDates);
      expect(status, equals(DayStatus.today));
    });

    test(
        'today with completed workout returns DayStatus.completed (completed takes priority)',
        () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final completedDates = {today};

      final status = getDayStatus(today, completedDates);
      expect(status, equals(DayStatus.completed));
    });

    Glados2(
      any.intInRange(2000, 2101),
      any.intInRange(1, 366),
    ).test(
      'exactly one status is assigned (exhaustive and mutually exclusive)',
      (year, dayOfYear) {
        final date = DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
        final dateOnly = DateTime(date.year, date.month, date.day);

        // Test with the date both in and out of completedDates
        final statusCompleted = getDayStatus(date, {dateOnly});
        final statusNotCompleted = getDayStatus(date, <DateTime>{});

        // When in completed set, must be completed
        expect(statusCompleted, equals(DayStatus.completed));

        // When not in completed set, must be either today or normal
        expect(
          statusNotCompleted == DayStatus.today ||
              statusNotCompleted == DayStatus.normal,
          isTrue,
          reason:
              'Status should be today or normal when not completed, got $statusNotCompleted',
        );

        // Verify exactly one value from the enum is returned (not null, not invalid)
        expect(DayStatus.values.contains(statusCompleted), isTrue);
        expect(DayStatus.values.contains(statusNotCompleted), isTrue);
      },
    );
  });
}
