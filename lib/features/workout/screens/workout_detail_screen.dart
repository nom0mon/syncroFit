import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../exercise_library/providers/exercise_provider.dart';
import '../providers/workout_provider.dart';

/// Displays the workout detail with all exercises listed, along with
/// a "Start Workout" button that navigates to the active session.
///
/// Validates: Requirement 7.1
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(workoutByIdProvider(workoutId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Detail'),
      ),
      body: workoutAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorDisplay(
          message: 'Failed to load workout',
          onRetry: () => ref.invalidate(workoutByIdProvider(workoutId)),
        ),
        data: (workout) {
          if (workout == null) {
            return ErrorDisplay(
              message: 'Workout not found',
              onRetry: () => ref.invalidate(workoutByIdProvider(workoutId)),
            );
          }
          return _WorkoutDetailContent(
            workout: workout,
            workoutId: workoutId,
          );
        },
      ),
    );
  }
}

class _WorkoutDetailContent extends ConsumerWidget {
  const _WorkoutDetailContent({
    required this.workout,
    required this.workoutId,
  });

  final Workout workout;
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Build a lookup of exercise id → name from the loaded exercise library.
    final exercises = ref.watch(exerciseProvider).allExercises;
    final nameById = <int, String>{};
    for (final e in exercises) {
      final id = int.tryParse(e.id);
      if (id != null) nameById[id] = e.name;
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Workout header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workout.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (workout.isGenerated)
                    Semantics(
                      label: 'AI Generated workout',
                      child: Chip(
                        avatar: Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        label: Text(
                          'AI Generated',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${workout.exercises.length} exercises • ${workout.estimatedDurationMinutes} min',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Exercise list
              ...workout.exercises.map(
                (exercise) => _ExerciseListItem(
                  exercise: exercise,
                  exerciseName: nameById[exercise.exerciseId] ??
                      'Exercise ${exercise.exerciseId}',
                ),
              ),
            ],
          ),
        ),

        // Workout actions
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (workout.isGenerated) ...[
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/dashboard/workout/$workoutId/customize',
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text('Customize Workout'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              FilledButton.icon(
              onPressed: () {
                context.go('/dashboard/workout/$workoutId/active');
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Workout'),
            ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseListItem extends StatelessWidget {
  const _ExerciseListItem({
    required this.exercise,
    required this.exerciseName,
  });

  final WorkoutExercise exercise;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine reps/duration display
    final detailText = exercise.durationSeconds > 0
        ? '${exercise.sets} sets • ${formatDuration(exercise.durationSeconds)} • ${exercise.restSeconds}s rest'
        : '${exercise.sets} sets • ${exercise.reps} reps • ${exercise.restSeconds}s rest';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Thumbnail placeholder
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Icon(
                Icons.fitness_center,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Exercise info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exerciseName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detailText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
