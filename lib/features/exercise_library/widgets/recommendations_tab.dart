import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../data/remote/providers.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../shared/models/models.dart';
import '../../profile/providers/profile_provider.dart';
import '../../workout/providers/workout_scheduler_provider.dart';
import '../../workout/widgets/workout_scheduler_widget.dart';

/// Recommendations tab displaying the user's personalized workout plan
/// organized by day of the week.
///
/// At the top, embeds the [WorkoutSchedulerWidget] (Mon–Sun horizontal row).
/// Below it, displays a scrollable list of scheduled workouts with details
/// (workout name, duration, exercise count per day).
///
/// If no recommendations exist, shows an empty state prompting the user
/// to generate a plan.
///
/// Uses [AutomaticKeepAliveClientMixin] to preserve state across tab switches.
///
/// Validates: Requirements 8.3, 9.5
class RecommendationsTab extends ConsumerStatefulWidget {
  const RecommendationsTab({super.key});

  @override
  ConsumerState<RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends ConsumerState<RecommendationsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Forces a refresh by calling refreshCaches with forceRefresh: true,
  /// which invalidates cache metadata and forces a backend fetch regardless
  /// of cache age, then reloads the workout schedule.
  ///
  /// Validates: Requirements 11.3, 11.4
  Future<void> _onRefresh() async {
    final syncEngine = ref.read(syncEngineProvider);
    await syncEngine.refreshCaches(forceRefresh: true);
    await ref.read(workoutSchedulerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final schedulerState = ref.watch(workoutSchedulerProvider);

    if (schedulerState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (schedulerState.errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_ErrorContent(message: schedulerState.errorMessage!)],
        ),
      );
    }

    if (schedulerState.scheduledWorkouts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [_EmptyStateContent()],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: _ScheduleContent(workouts: schedulerState.scheduledWorkouts),
    );
  }
}

/// Main content when scheduled workouts are available.
/// Shows the [WorkoutSchedulerWidget] at the top and a list of workouts below.
class _ScheduleContent extends StatelessWidget {
  const _ScheduleContent({required this.workouts});

  final List<ScheduledWorkout> workouts;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // WorkoutSchedulerWidget (Mon–Sun horizontal row)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: WorkoutSchedulerWidget(),
          ),
        ),

        // Section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              'Your Weekly Plan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),

        // List of scheduled workouts by day
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final workout = workouts[index];
                return _WorkoutDayCard(workout: workout);
              },
              childCount: workouts.length,
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.lg),
        ),
      ],
    );
  }
}

/// A card representing a scheduled workout for a specific day.
/// Shows the day name, workout name, and estimated duration.
class _WorkoutDayCard extends StatelessWidget {
  const _WorkoutDayCard({required this.workout});

  final ScheduledWorkout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = getWorkoutDayStatus(workout);

    final Color iconColor;
    final IconData statusIcon;

    switch (status) {
      case WorkoutDayStatus.completed:
        iconColor = theme.colorScheme.primary;
        statusIcon = Icons.check_circle;
      case WorkoutDayStatus.active:
        iconColor = theme.colorScheme.primary;
        statusIcon = Icons.play_circle_filled;
      case WorkoutDayStatus.upcoming:
        iconColor = theme.colorScheme.onSurfaceVariant;
        statusIcon = Icons.circle_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(statusIcon, color: iconColor),
        title: Text(workout.workoutName),
        subtitle: Text(
          '${_dayLabel(workout.dayOfWeek)} • ${workout.estimatedDurationMinutes} min',
        ),
        trailing: status == WorkoutDayStatus.active
            ? Chip(
                label: const Text('Today'),
                backgroundColor: theme.colorScheme.primaryContainer,
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              )
            : null,
      ),
    );
  }

  String _dayLabel(DayOfWeek day) {
    switch (day) {
      case DayOfWeek.monday:
        return 'Monday';
      case DayOfWeek.tuesday:
        return 'Tuesday';
      case DayOfWeek.wednesday:
        return 'Wednesday';
      case DayOfWeek.thursday:
        return 'Thursday';
      case DayOfWeek.friday:
        return 'Friday';
      case DayOfWeek.saturday:
        return 'Saturday';
      case DayOfWeek.sunday:
        return 'Sunday';
    }
  }
}

/// Empty state shown when no recommendations/scheduled workouts exist.
/// Prompts the user to generate a personalized workout plan.
class _EmptyStateContent extends ConsumerWidget {
  const _EmptyStateContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Recommendations Yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Generate a personalized workout plan based on your fitness goals and available days.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => _handleGeneratePlan(context, ref),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGeneratePlan(BuildContext context, WidgetRef ref) async {
    final profileAsync = ref.read(profileProvider);
    final profile = profileAsync.valueOrNull;

    if (profile == null) {
      // User hasn't set up their profile — navigate to profile setup
      context.go('/profile-setup');
      return;
    }

    // Profile exists — generate the workout plan
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating your workout plan...'),
        duration: Duration(seconds: 2),
      ),
    );

    final remoteRepo = ref.read(remoteWorkoutRepositoryProvider);
    final result = await remoteRepo.generateRecommendation();

    if (!context.mounted) return;

    switch (result) {
      case Success():
        // Refresh the workout scheduler to show the new plan
        ref.read(workoutSchedulerProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout plan generated!'),
            backgroundColor: Colors.green,
          ),
        );
      case Failure(error: final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate plan: ${error.message}'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }
}

/// Error state shown when loading the schedule fails.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load recommendations',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
