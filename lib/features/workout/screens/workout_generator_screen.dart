import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/models.dart';
import '../../exercise_library/providers/exercise_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/workout_generator_provider.dart';

/// Dedicated screen for the schedule-aware workout generator.
///
/// Generation is explicit: it only happens when the user presses the
/// persistent "Generate Workout" button (or "Regenerate Workout" once a plan
/// exists). Nothing is generated on navigation or load.
///
/// The layout is fully responsive — it uses [Column] + [Expanded] +
/// scrollable lists and wraps content so long exercise names never overflow.
class WorkoutGeneratorScreen extends ConsumerWidget {
  const WorkoutGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutGeneratorProvider);
    final notifier = ref.read(workoutGeneratorProvider.notifier);
    final exerciseState = ref.watch(exerciseProvider);

    // Build a lookup of exercise id (int) → name for resolving workout
    // exercises. Exercise.id is a String, so parse to int where possible.
    final exerciseNames = <int, String>{};
    for (final exercise in exerciseState.allExercises) {
      final id = int.tryParse(exercise.id);
      if (id != null) {
        exerciseNames[id] = exercise.name;
      }
    }

    final isGenerating = state.status == WorkoutGeneratorStatus.generating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Generator'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top: preferences summary + include/exclude entry points ──
            _PreferencesSection(
              state: state,
              exercises: exerciseState.allExercises,
              notifier: notifier,
            ),
            const Divider(height: 1),

            // ── Content area, switches on status ──
            Expanded(
              child: _ContentArea(
                state: state,
                exerciseNames: exerciseNames,
              ),
            ),

            // ── Persistent bottom generate/regenerate button ──
            _GenerateButtonBar(
              isGenerating: isGenerating,
              isGenerated: state.status == WorkoutGeneratorStatus.generated,
              onPressed: isGenerating
                  ? null
                  : () => _onGeneratePressed(context, ref, notifier),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles the generate action. Requires a profile — if none exists, routes
  /// to profile setup and shows a snackbar instead of generating.
  void _onGeneratePressed(
    BuildContext context,
    WidgetRef ref,
    WorkoutGeneratorNotifier notifier,
  ) {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set up your profile first to generate a workout.'),
        ),
      );
      context.push('/profile-setup');
      return;
    }
    notifier.generate();
  }
}

/// Scrollable top section showing the preferences summary and the
/// include/exclude entry-point buttons.
class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({
    required this.state,
    required this.exercises,
    required this.notifier,
  });

  final WorkoutGeneratorState state;
  final List<Exercise> exercises;
  final WorkoutGeneratorNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final includedCount = state.includedExerciseIds.length;
    final excludedCount = state.excludedExerciseIds.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Optionally choose exercises to prefer or exclude before generating.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // Wrap keeps the two buttons responsive on narrow screens.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openSelectionSheet(
                  context,
                  isInclude: true,
                ),
                icon: const Icon(Icons.thumb_up_alt_outlined),
                label: Text('Preferred ($includedCount)'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openSelectionSheet(
                  context,
                  isInclude: false,
                ),
                icon: const Icon(Icons.block),
                label: Text('Excluded ($excludedCount)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSelectionSheet(BuildContext context, {required bool isInclude}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExerciseSelectionSheet(
        isInclude: isInclude,
        exercises: exercises,
        notifier: notifier,
      ),
    );
  }
}

/// Bottom sheet listing exercises with a toggle for include or exclude.
///
/// Reads the live generator state so toggles reflect immediately.
class _ExerciseSelectionSheet extends ConsumerWidget {
  const _ExerciseSelectionSheet({
    required this.isInclude,
    required this.exercises,
    required this.notifier,
  });

  final bool isInclude;
  final List<Exercise> exercises;
  final WorkoutGeneratorNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(workoutGeneratorProvider);
    final selectedIds =
        isInclude ? state.includedExerciseIds : state.excludedExerciseIds;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                isInclude ? 'Preferred Exercises' : 'Excluded Exercises',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No exercises available.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    final id = int.tryParse(exercise.id);
                    final selected =
                        id != null && selectedIds.contains(id);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(exercise.name),
                      subtitle: Text(
                        exercise.muscleGroup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: id == null
                          ? null
                          : (_) {
                              if (isInclude) {
                                notifier.toggleIncluded(id);
                              } else {
                                notifier.toggleExcluded(id);
                              }
                            },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Switches the main content area based on the generator status.
class _ContentArea extends StatelessWidget {
  const _ContentArea({
    required this.state,
    required this.exerciseNames,
  });

  final WorkoutGeneratorState state;
  final Map<int, String> exerciseNames;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case WorkoutGeneratorStatus.idle:
        return const _CenteredHint(
          icon: Icons.auto_awesome,
          message:
              'Select your preferences and press Generate Workout to create your exercise set.',
        );
      case WorkoutGeneratorStatus.generating:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating...'),
            ],
          ),
        );
      case WorkoutGeneratorStatus.generated:
        if (state.generatedWorkouts.isEmpty) {
          return const _CenteredHint(
            icon: Icons.info_outline,
            message: 'No workouts were generated. Try adjusting your preferences.',
          );
        }
        return _GeneratedWorkoutList(
          workouts: state.generatedWorkouts,
          exerciseNames: exerciseNames,
        );
      case WorkoutGeneratorStatus.error:
        return _CenteredHint(
          icon: Icons.error_outline,
          message: state.errorMessage ?? 'Something went wrong. Please try again.',
          isError: true,
        );
    }
  }
}

/// Centered informational / hint / error message.
class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable list of generated workouts, one section per workout/day.
class _GeneratedWorkoutList extends StatelessWidget {
  const _GeneratedWorkoutList({
    required this.workouts,
    required this.exerciseNames,
  });

  final List<Workout> workouts;
  final Map<int, String> exerciseNames;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        return _WorkoutSection(
          workout: workouts[index],
          exerciseNames: exerciseNames,
        );
      },
    );
  }
}

/// A single generated workout: day label + name + duration + exercise cards.
class _WorkoutSection extends StatelessWidget {
  const _WorkoutSection({
    required this.workout,
    required this.exerciseNames,
  });

  final Workout workout;
  final Map<int, String> exerciseNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayLabel = _dayLabel(workout.dayOfWeek);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dayLabel != null)
            Text(
              dayLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            workout.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${workout.estimatedDurationMinutes} min • ${workout.exercises.length} exercises',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          // Single-column, vertically flowing cards — no horizontal overflow.
          ...workout.exercises.map(
            (we) => _ExerciseCard(
              workoutExercise: we,
              name: exerciseNames[we.exerciseId] ??
                  'Exercise #${we.exerciseId}',
            ),
          ),
        ],
      ),
    );
  }

  /// Converts a workout's dayOfWeek string ("1".."7" or a name) into a
  /// readable label. Returns null when it cannot be parsed.
  String? _dayLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final asNumber = int.tryParse(raw.trim());
    if (asNumber != null && asNumber >= 1 && asNumber <= 7) {
      return names[asNumber - 1];
    }

    final lower = raw.trim().toLowerCase();
    for (final name in names) {
      if (name.toLowerCase() == lower) return name;
    }
    return null;
  }
}

/// Responsive card for a single exercise within a generated workout.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.workoutExercise,
    required this.name,
  });

  final WorkoutExercise workoutExercise;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyLarge,
                    // Allow long names to wrap instead of overflowing.
                    softWrap: true,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _detailText(),
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

  String _detailText() {
    // Prefer sets x reps; fall back to a duration-based description.
    if (workoutExercise.reps > 0) {
      return '${workoutExercise.sets} x ${workoutExercise.reps} reps';
    }
    if (workoutExercise.durationSeconds > 0) {
      final secs = workoutExercise.durationSeconds;
      return '${workoutExercise.sets} x ${secs}s';
    }
    return '${workoutExercise.sets} sets';
  }
}

/// Persistent full-width bottom action bar.
class _GenerateButtonBar extends StatelessWidget {
  const _GenerateButtonBar({
    required this.isGenerating,
    required this.isGenerated,
    required this.onPressed,
  });

  final bool isGenerating;
  final bool isGenerated;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isGenerated ? 'Regenerate Workout' : 'Generate Workout';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}
