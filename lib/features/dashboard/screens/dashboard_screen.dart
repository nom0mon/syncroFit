import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/dashboard_provider.dart';

/// Dashboard screen matching the Figma "Home" design:
/// - Greeting header with logo and user name
/// - Dashboard card with Today's Summary and This Week stats
/// - Weekly activity bar chart
/// - Quick Actions row
///
/// Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SyncroFit',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.go(RouteNames.settings),
            icon: const Icon(Icons.person_outline),
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
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting card with logo
          _GreetingCard(theme: theme),
          const SizedBox(height: AppSpacing.md),

          // Dashboard stats card
          _DashboardStatsCard(state: state, theme: theme),
          const SizedBox(height: AppSpacing.md),

          // Weekly activity chart
          _WeeklyChart(state: state, theme: theme),
          const SizedBox(height: AppSpacing.lg),

          // Quick Actions
          _QuickActionsSection(theme: theme),
        ],
      ),
    );
  }
}

/// Greeting header card matching Figma: logo + "Hello, {username}!" + subtitle.
class _GreetingCard extends ConsumerWidget {
  const _GreetingCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userName = authState.user?.name ?? 'User';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Logo icon
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $userName!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Let's get working!",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

/// Dashboard card with bordered sub-sections for Today's Summary and This Week.
class _DashboardStatsCard extends StatelessWidget {
  const _DashboardStatsCard({required this.state, required this.theme});

  final DashboardState state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final workout = state.todaysWorkout;
    final exerciseCount = workout?.exercises.length ?? 0;
    final duration = workout?.estimatedDurationMinutes ?? 0;

    return Card(
      child: InkWell(
        onTap: workout != null
            ? () => context.go('/dashboard/workout/${workout.id}')
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Today's Summary
                    Expanded(
                      child: _StatBox(
                        title: "Today's Summary",
                        items: [
                          _StatItem(
                            icon: Icons.fitness_center,
                            label: 'Exercises',
                            value: '$exerciseCount/$exerciseCount',
                          ),
                          _StatItem(
                            icon: Icons.access_time,
                            label: 'Duration',
                            value: '$duration min',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // This Week
                    Expanded(
                      child: _StatBox(
                        title: 'This week',
                        items: [
                          _StatItem(
                            icon: Icons.fitness_center,
                            label: 'Workouts',
                            value: '${state.completedDays}',
                          ),
                          _StatItem(
                            icon: Icons.access_time,
                            label: 'Duration',
                            value: '${state.completedDays * duration} min',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bordered stat box matching the Figma inner cards.
class _StatBox extends StatelessWidget {
  const _StatBox({required this.title, required this.items});

  final String title;
  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item.icon, size: 16),
                        const SizedBox(width: 4),
                        const Icon(Icons.access_time, size: 14),
                      ],
                    ),
                    Text(
                      item.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      item.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// Weekly activity bar chart matching Figma — Mon–Sun bars.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.state, required this.theme});

  final DashboardState state;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
    // Mock activity data — first N days are "completed"
    final completedCount = state.completedDays.clamp(0, 7);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final isCompleted = index < completedCount;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: isCompleted ? 60 : 20,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: days
                  .map((d) => Text(
                        d,
                        style: theme.textTheme.labelSmall,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick Actions row matching Figma: Start Workout, BMI Calculator, View Schedule, Add Photo.
class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Divider(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _QuickActionButton(
              icon: Icons.play_arrow,
              label: 'Start\nWorkout',
              onTap: () {
                // Navigate to first workout if available
                context.go('/dashboard/workout/workout-001');
              },
            ),
            _QuickActionButton(
              icon: Icons.calculate_outlined,
              label: 'BMI\nCalculator',
              onTap: () => context.go(RouteNames.assessment),
            ),
            _QuickActionButton(
              icon: Icons.calendar_today_outlined,
              label: 'View\nSchedule',
              onTap: () => context.go(RouteNames.progress),
            ),
            _QuickActionButton(
              icon: Icons.camera_alt_outlined,
              label: 'Add\nPhoto',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo feature coming soon')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual quick action button matching Figma: bordered square with icon + label.
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
