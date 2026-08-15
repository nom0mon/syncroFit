import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../data/remote/providers.dart';
import '../../../shared/models/models.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/workout_scheduler_provider.dart';

/// Displays a Mon–Sun horizontal row of day cards showing the user's
/// weekly workout schedule.
///
/// Visual distinction:
/// - Completed (past): grey background + checkmark icon
/// - Active (today): highlighted primary color background
/// - Upcoming (future): standard outlined card
///
/// Tapping a day with a workout navigates to the workout detail screen.
/// If no workouts are scheduled, shows a "Generate Plan" prompt.
///
/// Validates: Requirements 9.1, 9.3, 9.4, 9.5
class WorkoutSchedulerWidget extends ConsumerWidget {
  const WorkoutSchedulerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulerState = ref.watch(workoutSchedulerProvider);

    if (schedulerState.isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (schedulerState.errorMessage != null) {
      return _ErrorState(message: schedulerState.errorMessage!);
    }

    if (schedulerState.scheduledWorkouts.isEmpty) {
      return const _EmptyState();
    }

    return _ScheduleRow(workouts: schedulerState.scheduledWorkouts);
  }
}

/// Displays the Mon–Sun horizontal scrollable row of day cards.
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.workouts});

  final List<ScheduledWorkout> workouts;

  @override
  Widget build(BuildContext context) {
    // Build a map from DayOfWeek to ScheduledWorkout for quick lookup.
    final workoutByDay = <DayOfWeek, ScheduledWorkout>{};
    for (final workout in workouts) {
      workoutByDay[workout.dayOfWeek] = workout;
    }

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: DayOfWeek.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final day = DayOfWeek.values[index];
          final workout = workoutByDay[day];
          return _DayCard(day: day, workout: workout);
        },
      ),
    );
  }
}

/// A single day card showing the abbreviated day name and workout status.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, this.workout});

  final DayOfWeek day;
  final ScheduledWorkout? workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status =
        workout != null ? getWorkoutDayStatus(workout!) : _inferDayStatus(day);

    final dayLabel = _abbreviatedDay(day);
    final hasWorkout = workout != null;

    // Determine visual styling based on status.
    final Color backgroundColor;
    final Color foregroundColor;
    final BoxBorder? border;
    final Widget? statusIcon;

    switch (status) {
      case WorkoutDayStatus.completed:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        foregroundColor = theme.colorScheme.onSurfaceVariant;
        border = null;
        statusIcon = hasWorkout
            ? Icon(Icons.check, size: 16, color: foregroundColor)
            : null;
      case WorkoutDayStatus.active:
        backgroundColor = theme.colorScheme.primary;
        foregroundColor = theme.colorScheme.onPrimary;
        border = null;
        statusIcon = hasWorkout
            ? Icon(Icons.fitness_center, size: 16, color: foregroundColor)
            : null;
      case WorkoutDayStatus.upcoming:
        backgroundColor = theme.colorScheme.surface;
        foregroundColor = theme.colorScheme.onSurface;
        border = Border.all(color: theme.colorScheme.outlineVariant);
        statusIcon = hasWorkout
            ? Icon(Icons.fitness_center, size: 16, color: foregroundColor)
            : null;
    }

    return GestureDetector(
      onTap: hasWorkout ? () => _navigateToWorkout(context) : null,
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: border,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (statusIcon != null) statusIcon,
            if (hasWorkout) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${workout!.estimatedDurationMinutes}m',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foregroundColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToWorkout(BuildContext context) {
    context.go('/dashboard/workout/${workout!.workoutId}');
  }

  /// Infer a day's status when there is no workout assigned.
  /// This is purely visual — days without workouts still show their
  /// position relative to today.
  WorkoutDayStatus _inferDayStatus(DayOfWeek day) {
    final todayIndex = DateTime.now().weekday - 1;
    final dayIndex = day.index;

    if (dayIndex < todayIndex) return WorkoutDayStatus.completed;
    if (dayIndex == todayIndex) return WorkoutDayStatus.active;
    return WorkoutDayStatus.upcoming;
  }

  /// Returns a 3-letter abbreviated day name.
  String _abbreviatedDay(DayOfWeek day) {
    switch (day) {
      case DayOfWeek.monday:
        return 'Mon';
      case DayOfWeek.tuesday:
        return 'Tue';
      case DayOfWeek.wednesday:
        return 'Wed';
      case DayOfWeek.thursday:
        return 'Thu';
      case DayOfWeek.friday:
        return 'Fri';
      case DayOfWeek.saturday:
        return 'Sat';
      case DayOfWeek.sunday:
        return 'Sun';
    }
  }
}

/// Empty state displayed when no workouts are scheduled.
/// Shows a "Generate Plan" prompt to guide the user.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No workout plan yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Generate a personalized workout plan based on your goals and availability.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => _handleGeneratePlan(context, ref),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Plan'),
          ),
        ],
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

/// Error state shown when the schedule fails to load.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: Text(
          'Failed to load schedule',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
