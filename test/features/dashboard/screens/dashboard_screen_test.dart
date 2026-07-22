import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:synchrofit/features/dashboard/providers/dashboard_provider.dart';
import 'package:synchrofit/features/dashboard/screens/dashboard_screen.dart';
import 'package:synchrofit/features/dashboard/widgets/calendar_grid_widget.dart';
import 'package:synchrofit/features/dashboard/widgets/completed_sessions_widget.dart';
import 'package:synchrofit/features/dashboard/widgets/weekly_load_chart_widget.dart';
import 'package:synchrofit/shared/models/completed_exercise.dart';
import 'package:synchrofit/shared/models/workout_session.dart';
import 'package:synchrofit/shared/widgets/edge_fade_gradient.dart';

void main() {
  setUpAll(() {
    // Prevent google_fonts from making HTTP requests in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Helper that wraps DashboardScreen in a ProviderScope with a mocked
  /// dashboardProvider returning the given [state].
  Widget buildTestWidget({required DashboardState state}) {
    return ProviderScope(
      overrides: [
        dashboardProvider.overrideWith(() => _FakeDashboardNotifier(state)),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
      ),
    );
  }

  group('DashboardScreen composition', () {
    final testState = DashboardState(
      sessions: [
        WorkoutSession(
          id: '1',
          workoutId: 'w1',
          workoutName: 'Upper Body',
          completedAt: DateTime.now(),
          totalDurationSeconds: 2700,
          exercisesCompleted: 5,
          exercises: [
            const CompletedExercise(
              exerciseId: 'e1',
              exerciseName: 'Bench Press',
              setsCompleted: 3,
              repsOrDuration: 10,
            ),
          ],
        ),
      ],
    );

    testWidgets('renders CalendarGridWidget', (tester) async {
      await tester.pumpWidget(buildTestWidget(state: testState));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarGridWidget), findsOneWidget);
    });

    testWidgets('renders WeeklyLoadChartWidget', (tester) async {
      await tester.pumpWidget(buildTestWidget(state: testState));
      await tester.pumpAndSettle();

      expect(find.byType(WeeklyLoadChartWidget), findsOneWidget);
    });

    testWidgets('renders CompletedSessionsWidget', (tester) async {
      await tester.pumpWidget(buildTestWidget(state: testState));
      await tester.pumpAndSettle();

      expect(find.byType(CompletedSessionsWidget), findsOneWidget);
    });

    testWidgets('renders two EdgeFadeGradient widgets (top and bottom)',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(state: testState));
      await tester.pumpAndSettle();

      final gradients = find.byType(EdgeFadeGradient);
      expect(gradients, findsNWidgets(2));

      // Verify one is top and one is bottom.
      final widgets = tester.widgetList<EdgeFadeGradient>(gradients).toList();
      final topGradients = widgets.where((w) => w.isTop).toList();
      final bottomGradients = widgets.where((w) => !w.isTop).toList();
      expect(topGradients, hasLength(1));
      expect(bottomGradients, hasLength(1));
    });
  });
}

/// A fake [DashboardNotifier] that immediately returns the provided state.
class _FakeDashboardNotifier extends DashboardNotifier {
  _FakeDashboardNotifier(this._state);

  final DashboardState _state;

  @override
  Future<DashboardState> build() async => _state;
}
