import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/notification_settings_launcher.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/scheduled_workout.dart';
import '../../../shared/widgets/edge_fade_gradient.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/safe_layout.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../workout/providers/workout_scheduler_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/calendar_grid_widget.dart';
import '../widgets/weekly_load_chart_widget.dart';

/// Dashboard screen with calendar, weekly load, and completed-session states.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final scheduledWorkouts = ref.watch(scheduledWorkoutsProvider);
    final sessionUsername =
        ref.watch(authStateProvider).user?.username.trim() ?? '';
    final profileUsername =
        ref.watch(profileProvider).valueOrNull?.username.trim() ?? '';
    final username =
        sessionUsername.isNotEmpty ? sessionUsername : profileUsername;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Open settings',
            onPressed: () => _openSettingsOverlay(context),
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (state) => _DashboardContent(
          state: state,
          username: username,
          scheduledWorkouts: scheduledWorkouts,
        ),
      ),
    );
  }

  void _openSettingsOverlay(BuildContext context) {
    final providerContainer = ProviderScope.containerOf(context);

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            UncontrolledProviderScope(
          container: providerContainer,
          child: const _FullScreenSettingsMenu(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}

Future<void> _openSystemNotificationSettings(BuildContext context) async {
  final opened = await NotificationSettingsLauncher.open();
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open phone settings.')),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({
    required this.state,
    required this.username,
    required this.scheduledWorkouts,
  });

  final DashboardState state;
  final String username;
  final List<ScheduledWorkout> scheduledWorkouts;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  static const double _dashboardPanelMinWidth = 320;

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final scheduledForDate = widget.scheduledWorkouts
        .where(
            (workout) => workout.dayOfWeek.index + 1 == _selectedDate.weekday)
        .toList();
    final scheduledWeekdays = widget.scheduledWorkouts
        .map((workout) => workout.dayOfWeek.index + 1)
        .toSet();

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: 100,
            ),
            child: ResponsiveConstrainedPage(
              key: const Key('dashboard-content'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.username.isEmpty
                        ? 'Hello!'
                        : 'Hello, ${widget.username}!',
                    key: const Key('dashboard-welcome-message'),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const SectionHeader(title: 'Overview'),
                  const SizedBox(height: AppSpacing.sm),
                  AdaptiveGridList(
                    key: const Key('dashboard-stat-grid'),
                    minItemWidth: ResponsiveStandards.minCardWidth,
                    maxColumns: 2,
                    children: [
                      _DashboardStatCard(
                        key: const Key('dashboard-stat-weekly'),
                        icon: Icons.event_available_outlined,
                        label: 'Weekly progress',
                        value:
                            '${widget.state.completedDays} of ${widget.state.plannedDays} days',
                      ),
                      _DashboardStatCard(
                        key: const Key('dashboard-stat-goal'),
                        icon: Icons.track_changes_outlined,
                        label: 'Goal progress',
                        value: '${widget.state.goalPercentage}%',
                      ),
                      _DashboardStatCard(
                        key: const Key('dashboard-stat-streak'),
                        icon: Icons.local_fire_department_outlined,
                        label: 'Current streak',
                        value: '${widget.state.streak} '
                            '${widget.state.streak == 1 ? 'day' : 'days'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AdaptiveGridList(
                    key: const Key('dashboard-adaptive-grid'),
                    minItemWidth: _dashboardPanelMinWidth,
                    maxColumns: 2,
                    children: [
                      CalendarGridWidget(
                        completedDates: widget.state.completedDates,
                        selectedDate: _selectedDate,
                        scheduledWeekdays: scheduledWeekdays,
                        onDateSelected: _onDateSelected,
                      ),
                      WeeklyLoadChartWidget(sessions: widget.state.history),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SelectedDateSchedule(
                    workouts: scheduledForDate,
                    selectedDate: _selectedDate,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: EdgeFadeGradient(isTop: true),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: EdgeFadeGradient(isTop: false),
          ),
        ],
      ),
    );
  }

  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = date);
  }
}

class _SelectedDateSchedule extends StatelessWidget {
  const _SelectedDateSchedule({
    required this.workouts,
    required this.selectedDate,
  });

  final List<ScheduledWorkout> workouts;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}';
    return Column(
      key: const Key('selected-date-schedule'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'EXERCISE SCHEDULE', trailingLabel: dateLabel),
        const SizedBox(height: AppSpacing.sm),
        if (workouts.isEmpty)
          const ResponsiveCard(
            margin: EdgeInsets.zero,
            child: Text('No workout scheduled for this day.'),
          )
        else
          for (final workout in workouts) ...[
            ResponsiveCard(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fitness_center),
                title: Text(workout.workoutName),
                subtitle: Text(
                  '${workout.estimatedDurationMinutes} min scheduled workout',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.go('/dashboard/workout/${workout.workoutId}'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '$label: $value',
      child: ResponsiveCard(
        margin: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen settings menu exposed by the dashboard hamburger action.
///
/// Every destination listed here has a real release route or system action.
class _FullScreenSettingsMenu extends ConsumerWidget {
  const _FullScreenSettingsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveConstrainedPage(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AppSpacing.md,
                  0,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Settings',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close settings',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () => _openRoute(context, RouteNames.profileView),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('App Notifications'),
                subtitle: const Text('Manage in phone settings'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openSystemNotificationSettings(context),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                onTap: () => _openRoute(context, RouteNames.changePassword),
              ),
              const Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark Mode'),
                value: isDarkMode,
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRoute(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.push(route);
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SafeScrollableDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go(RouteNames.login);
    }
  }
}
