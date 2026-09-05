import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchrofit/features/dashboard/providers/dashboard_provider.dart';
import 'package:synchrofit/features/settings/providers/settings_provider.dart';
import 'package:synchrofit/features/dashboard/screens/dashboard_screen.dart';
import 'package:synchrofit/features/dashboard/widgets/calendar_grid_widget.dart';
import 'package:synchrofit/features/dashboard/widgets/completed_sessions_widget.dart';
import 'package:synchrofit/features/dashboard/widgets/weekly_load_chart_widget.dart';
import 'package:synchrofit/shared/widgets/error_display.dart';
import 'package:synchrofit/shared/widgets/loading_indicator.dart';

import '../../../support/responsive_test_harness.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  Widget dashboardWith(DashboardNotifier Function() createNotifier) {
    return ProviderScope(
      overrides: [
        dashboardProvider.overrideWith(createNotifier),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const DashboardScreen(),
    );
  }

  group('dashboard responsive layout', () {
    testWidgets('uses one readable panel column on a compact phone',
        (tester) async {
      await tester.pumpResponsiveWidget(
        dashboardWith(
          () => _DataDashboardNotifier(const DashboardState(history: [])),
        ),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
      );

      final weeklyStat =
          tester.getRect(find.byKey(const Key('dashboard-stat-weekly')));
      final goalStat =
          tester.getRect(find.byKey(const Key('dashboard-stat-goal')));
      final calendar = tester.getRect(find.byType(CalendarGridWidget));
      final chart = tester.getRect(find.byType(WeeklyLoadChartWidget));
      expect(goalStat.top, greaterThanOrEqualTo(weeklyStat.bottom));
      expect(chart.top, greaterThanOrEqualTo(calendar.bottom));
      expect(find.byType(CompletedSessionsWidget), findsOneWidget);
    });

    testWidgets('uses two readable panel columns on a tablet', (tester) async {
      await tester.pumpResponsiveWidget(
        dashboardWith(
          () => _DataDashboardNotifier(const DashboardState(history: [])),
        ),
        configuration: ResponsiveTestConfiguration.tablet,
        settle: true,
      );

      final weeklyStat =
          tester.getRect(find.byKey(const Key('dashboard-stat-weekly')));
      final goalStat =
          tester.getRect(find.byKey(const Key('dashboard-stat-goal')));
      final calendar = tester.getRect(find.byType(CalendarGridWidget));
      final chart = tester.getRect(find.byType(WeeklyLoadChartWidget));
      expect(goalStat.left, greaterThan(weeklyStat.left));
      expect(goalStat.top, closeTo(weeklyStat.top, 0.1));
      expect(chart.left, greaterThan(calendar.left));
      expect(chart.top, closeTo(calendar.top, 0.1));
    });

    testWidgets('constrains dashboard panels at large tablet widths',
        (tester) async {
      const configuration = ResponsiveTestConfiguration(
        name: 'large-tablet',
        size: Size(1200, 900),
      );

      await tester.pumpResponsiveWidget(
        dashboardWith(
          () => _DataDashboardNotifier(const DashboardState(history: [])),
        ),
        configuration: configuration,
        settle: true,
      );

      final gridSize = tester.getSize(
        find.byKey(const Key('dashboard-adaptive-grid')),
      );
      expect(gridSize.width, lessThanOrEqualTo(840));
      expect(
        tester.getRect(find.byType(CalendarGridWidget)).left,
        greaterThan(150),
      );
      expect(
        tester.getRect(find.byType(WeeklyLoadChartWidget)).right,
        lessThan(configuration.size.width - 150),
      );
    });

    testWidgets('preserves the dashboard empty state at 200 percent text',
        (tester) async {
      await tester.pumpResponsiveWidget(
        dashboardWith(
          () => _DataDashboardNotifier(const DashboardState(history: [])),
        ),
        configuration: ResponsiveTestConfiguration.largeText,
        settle: true,
      );

      expect(
        find.text(
          'No finished workouts landed on this day yet. '
          'Pick another date or log a new session.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('preserves loading state', (tester) async {
      await tester.pumpResponsiveWidget(
        dashboardWith(_PendingDashboardNotifier.new),
        configuration: ResponsiveTestConfiguration.compactPhone,
      );
      await tester.pump();

      expect(find.byType(LoadingIndicator), findsOneWidget);
    });

    testWidgets('preserves actionable error state', (tester) async {
      await tester.pumpResponsiveWidget(
        dashboardWith(_ErrorDashboardNotifier.new),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
      );

      expect(find.byType(ErrorDisplay), findsOneWidget);
      expect(find.textContaining('dashboard unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('settings menu exposes only real release destinations',
        (tester) async {
      await tester.pumpResponsiveWidget(
        dashboardWith(
          () => _DataDashboardNotifier(const DashboardState(history: [])),
        ),
        configuration: ResponsiveTestConfiguration.largeText,
        settle: true,
      );

      await tester.tap(find.byTooltip('Open settings'));
      await tester.pumpAndSettle();

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Local Notification Preferences'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Notifications have been removed.'), findsNothing);
      expect(find.text('Search'), findsNothing);
      expect(find.textContaining('Trainer'), findsNothing);
    });
  });
}

class _DataDashboardNotifier extends DashboardNotifier {
  _DataDashboardNotifier(this.value);

  final DashboardState value;

  @override
  Future<DashboardState> build() async => value;
}

class _PendingDashboardNotifier extends DashboardNotifier {
  final Completer<DashboardState> _completer = Completer<DashboardState>();

  @override
  Future<DashboardState> build() => _completer.future;
}

class _ErrorDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardState> build() async {
    throw StateError('dashboard unavailable');
  }
}
