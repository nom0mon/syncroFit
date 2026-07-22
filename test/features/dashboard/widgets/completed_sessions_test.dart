import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, setUpAll, setUp, tearDown;
import 'package:synchrofit/features/dashboard/utils/session_display_utils.dart';
import 'package:synchrofit/features/dashboard/widgets/completed_sessions_widget.dart';
import 'package:synchrofit/shared/models/completed_exercise.dart';
import 'package:synchrofit/shared/models/workout_session.dart';
import 'package:synchrofit/shared/widgets/section_header.dart';

void main() {
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
        final date = DateTime(year, month, 1);
        final result = formatDateDisplay(date);

        expect(result, '${monthNames[month - 1]} ${date.day}, $year');
      },
    );

    Glados(any.intInRange(2000, 2101)).test(
      'day portion never has leading zeros',
      (year) {
        for (int day = 1; day <= 9; day++) {
          final date = DateTime(year, 1, day);
          final result = formatDateDisplay(date);
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

  group('CompletedSessionsWidget', () {
    // The CompletedSessionsWidget uses AppTextStyles which calls
    // GoogleFonts.getFont('Geist', ...). In the test environment the Geist
    // font is not available, so we suppress those errors during widget tests.
    late void Function(FlutterErrorDetails)? originalOnError;

    setUp(() {
      originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        // Suppress google_fonts "No font family by name" errors in tests.
        if (details.exception.toString().contains('No font family by name')) {
          return;
        }
        originalOnError?.call(details);
      };
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
    });

    testWidgets('renders section header with "COMPLETED SESSIONS"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedSessionsWidget(
              sessions: const [],
              selectedDate: DateTime(2026, 4, 25),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SectionHeader), findsOneWidget);
      expect(find.text('COMPLETED SESSIONS'), findsOneWidget);
    });

    testWidgets('renders trailing label with session count', (tester) async {
      final sessions = [
        WorkoutSession(
          id: '1',
          workoutId: 'w1',
          workoutName: 'Push Day',
          completedAt: DateTime(2026, 4, 25),
          totalDurationSeconds: 2700,
          exercisesCompleted: 5,
          exercises: const [
            CompletedExercise(
              exerciseId: 'e1',
              exerciseName: 'Bench Press',
              setsCompleted: 3,
              repsOrDuration: 10,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedSessionsWidget(
              sessions: sessions,
              selectedDate: DateTime(2026, 4, 25),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1 ON DAY'), findsOneWidget);
    });

    testWidgets('displays formatted selected date', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedSessionsWidget(
              sessions: const [],
              selectedDate: DateTime(2026, 4, 25),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('April 25, 2026'), findsOneWidget);
    });

    testWidgets('shows empty state message when no sessions exist',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedSessionsWidget(
              sessions: const [],
              selectedDate: DateTime(2026, 4, 25),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'No finished workouts landed on this day yet. '
          'Pick another date or log a new session.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders session rows when sessions exist', (tester) async {
      final sessions = [
        WorkoutSession(
          id: '1',
          workoutId: 'w1',
          workoutName: 'Push Day',
          completedAt: DateTime(2026, 4, 25),
          totalDurationSeconds: 2700,
          exercisesCompleted: 5,
          exercises: const [],
        ),
        WorkoutSession(
          id: '2',
          workoutId: 'w2',
          workoutName: 'Pull Day',
          completedAt: DateTime(2026, 4, 25),
          totalDurationSeconds: 3600,
          exercisesCompleted: 4,
          exercises: const [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedSessionsWidget(
              sessions: sessions,
              selectedDate: DateTime(2026, 4, 25),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Push Day'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('Pull Day'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
    });

    testWidgets('does not show empty state when sessions exist',
        (tester) async {
      final sessions = [
        WorkoutSession(
          id: '1',
          workoutId: 'w1',
          workoutName: 'Leg Day',
          completedAt: DateTime(2026, 4, 25),
          totalDurationSeconds: 1800,
          exercisesCompleted: 3,
          exercises: const [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedSessionsWidget(
              sessions: sessions,
              selectedDate: DateTime(2026, 4, 25),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'No finished workouts landed on this day yet. '
          'Pick another date or log a new session.',
        ),
        findsNothing,
      );
    });
  });
}
