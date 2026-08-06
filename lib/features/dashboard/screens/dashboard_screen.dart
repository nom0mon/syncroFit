import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/edge_fade_gradient.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/calendar_grid_widget.dart';
import '../widgets/completed_sessions_widget.dart';
import '../widgets/weekly_load_chart_widget.dart';

/// Dashboard screen with Geist-inspired layout:
/// - CalendarGridWidget showing monthly workout completion
/// - WeeklyLoadChartWidget with 4-week volume bars
/// - CompletedSessionsWidget for selected date details
/// - EdgeFadeGradient overlays at top and bottom
///
/// Validates: Requirements 4.7, 4.8, 6.1, 10.1, 10.2, 11.3
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => _openSettingsOverlay(context, ref),
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
        data: (state) => _DashboardContent(state: state),
      ),
    );
  }

  void _openSettingsOverlay(BuildContext context, WidgetRef ref) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _FullScreenSettingsMenu(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}

/// The main dashboard body composed of CalendarGrid, WeeklyLoadChart, and
/// CompletedSessions within a Stack that includes edge fade gradients.
class _DashboardContent extends StatefulWidget {
  const _DashboardContent({required this.state});

  final DashboardState state;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final completedDates = widget.state.completedDates;
    final sessionsForDate = widget.state.sessionsForDate(_selectedDate);

    return Stack(
      children: [
        // Scrollable content
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CalendarGridWidget(
                completedDates: completedDates,
                selectedDate: _selectedDate,
                onDateSelected: _onDateSelected,
              ),
              const SizedBox(height: AppSpacing.md),
              WeeklyLoadChartWidget(
                sessions: widget.state.sessions,
              ),
              const SizedBox(height: AppSpacing.md),
              CompletedSessionsWidget(
                sessions: sessionsForDate,
                selectedDate: _selectedDate,
              ),
            ],
          ),
        ),
        // Top edge fade gradient
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: EdgeFadeGradient(isTop: true),
        ),
        // Bottom edge fade gradient
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: EdgeFadeGradient(isTop: false),
        ),
      ],
    );
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }
}

/// Full-screen settings menu overlay triggered by the hamburger icon.
/// Covers the entire screen including the bottom navigation bar.
class _FullScreenSettingsMenu extends ConsumerWidget {
  const _FullScreenSettingsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and close (hamburger) button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.menu),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Menu items
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings/edit-profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notification Settings'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings/notifications');
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings/change-password');
              },
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark Mode'),
              value: isDarkMode,
              onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
            ),
          ],
        ),
      ),
    );
  }
}
