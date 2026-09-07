import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/safe_layout.dart';
import '../../exercise_library/providers/exercise_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/workout_generator_provider.dart';
import '../providers/workout_scheduler_provider.dart';

/// Dedicated screen for the schedule-aware workout generator.
///
/// Generation is explicit: it only happens when the user presses the
/// persistent "Generate Workout" button (or "Regenerate Workout" once a plan
/// exists). Nothing is generated on navigation or load.
class WorkoutGeneratorScreen extends ConsumerWidget {
  const WorkoutGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutGeneratorProvider);
    final notifier = ref.read(workoutGeneratorProvider.notifier);
    final exerciseState = ref.watch(exerciseProvider);

    final exerciseNames = <int, String>{};
    for (final exercise in exerciseState.allExercises) {
      final id = int.tryParse(exercise.id);
      if (id != null) exerciseNames[id] = exercise.displayName;
    }

    final isGenerating = state.status == WorkoutGeneratorStatus.generating;
    final isAccepting = state.status == WorkoutGeneratorStatus.accepting;
    final hasDraft = state.status == WorkoutGeneratorStatus.generated ||
        state.status == WorkoutGeneratorStatus.accepting;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Workout Generator')),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ResponsiveConstrainedPage(
                child: SingleChildScrollView(
                  key: const Key('workout-generator-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PreferencesSection(
                        state: state,
                        exercises: exerciseState.allExercises,
                        notifier: notifier,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.md),
                      _ContentArea(
                        state: state,
                        exerciseNames: exerciseNames,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeBottomActionBar(
              avoidKeyboard: false,
              child: _GeneratorActions(
                isGenerating: isGenerating,
                isAccepting: isAccepting,
                hasDraft: hasDraft,
                onGenerate: isGenerating || isAccepting
                    ? null
                    : () => _onGeneratePressed(context, ref, notifier),
                onAccept: hasDraft && !isAccepting
                    ? () => _onAcceptPressed(context, ref, notifier)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _onAcceptPressed(
    BuildContext context,
    WidgetRef ref,
    WorkoutGeneratorNotifier notifier,
  ) async {
    final accepted = await notifier.acceptPlan();
    if (!context.mounted) return;
    if (accepted) {
      await ref.read(workoutSchedulerProvider.notifier).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout plan accepted and scheduled.')),
      );
      context.go('/exercises');
    }
  }
}

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferences',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Optionally choose exercises to prefer or exclude before generating.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        AdaptiveGridList(
          minItemWidth: 220,
          maxColumns: 2,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
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
    );
  }

  void _openSelectionSheet(BuildContext context, {required bool isInclude}) {
    showSafeModalBottomSheet<void>(
      context: context,
      title: Text(
        isInclude ? 'Preferred Exercises' : 'Excluded Exercises',
      ),
      bottomAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ),
      builder: (_) => _ExerciseSelectionSheet(
        isInclude: isInclude,
        exercises: exercises,
        notifier: notifier,
        initiallySelectedIds:
            isInclude ? state.includedExerciseIds : state.excludedExerciseIds,
      ),
    );
  }
}

/// A keyboard-safe, height-constrained exercise selection sheet.
///
/// [SafeScrollableBottomSheet] owns scrolling, so long exercise lists remain
/// reachable while its Done action stays visible above system and keyboard
/// insets. Selection state is local because modal routes may be mounted above
/// the provider scope that opened them.
class _ExerciseSelectionSheet extends StatefulWidget {
  const _ExerciseSelectionSheet({
    required this.isInclude,
    required this.exercises,
    required this.notifier,
    required this.initiallySelectedIds,
  });

  final bool isInclude;
  final List<Exercise> exercises;
  final WorkoutGeneratorNotifier notifier;
  final Set<int> initiallySelectedIds;

  @override
  State<_ExerciseSelectionSheet> createState() =>
      _ExerciseSelectionSheetState();
}

class _ExerciseSelectionSheetState extends State<_ExerciseSelectionSheet> {
  late final Set<int> _selectedIds = Set<int>.of(widget.initiallySelectedIds);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'No exercises available.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final exercise in widget.exercises)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: int.tryParse(exercise.id) != null &&
                _selectedIds.contains(int.parse(exercise.id)),
            title: Text(exercise.displayName),
            subtitle: Text(exercise.displayMuscleGroup),
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: int.tryParse(exercise.id) == null
                ? null
                : (_) {
                    final id = int.parse(exercise.id);
                    setState(() {
                      if (_selectedIds.contains(id)) {
                        _selectedIds.remove(id);
                      } else {
                        _selectedIds.add(id);
                      }
                    });
                    if (widget.isInclude) {
                      widget.notifier.toggleIncluded(id);
                    } else {
                      widget.notifier.toggleExcluded(id);
                    }
                  },
          ),
      ],
    );
  }
}

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
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Generating...'),
            ],
          ),
        );
      case WorkoutGeneratorStatus.generated:
      case WorkoutGeneratorStatus.accepting:
      case WorkoutGeneratorStatus.accepted:
        if (state.generatedWorkouts.isEmpty) {
          return const _CenteredHint(
            icon: Icons.info_outline,
            message:
                'No workouts were generated. Try adjusting your preferences.',
          );
        }
        return _GeneratedWorkoutList(
          workouts: state.generatedWorkouts,
          exerciseNames: exerciseNames,
        );
      case WorkoutGeneratorStatus.error:
        return _CenteredHint(
          icon: Icons.error_outline,
          message:
              state.errorMessage ?? 'Something went wrong. Please try again.',
          isError: true,
        );
    }
  }
}

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
    final color =
        isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Vertically flowing generated content. The page-level scroll view is the
/// single scroll owner, which keeps the persistent completion action visible.
class _GeneratedWorkoutList extends StatelessWidget {
  const _GeneratedWorkoutList({
    required this.workouts,
    required this.exerciseNames,
  });

  final List<Workout> workouts;
  final Map<int, String> exerciseNames;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final workout in workouts)
          _WorkoutSection(
            workout: workout,
            exerciseNames: exerciseNames,
          ),
      ],
    );
  }
}

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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            workout.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${workout.estimatedDurationMinutes} min • ${workout.exercises.length} exercises',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final workoutExercise in workout.exercises)
            _ExerciseCard(
              workoutExercise: workoutExercise,
              name: exerciseNames[workoutExercise.exerciseId] ??
                  'Exercise #${workoutExercise.exerciseId}',
            ),
        ],
      ),
    );
  }

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

    return ResponsiveCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _detailText(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _detailText() {
    if (workoutExercise.reps > 0) {
      return '${workoutExercise.sets} x ${workoutExercise.reps} reps';
    }
    if (workoutExercise.durationSeconds > 0) {
      return '${workoutExercise.sets} x ${workoutExercise.durationSeconds}s';
    }
    return '${workoutExercise.sets} sets';
  }
}

class _GeneratorActions extends StatelessWidget {
  const _GeneratorActions({
    required this.isGenerating,
    required this.isAccepting,
    required this.hasDraft,
    required this.onGenerate,
    required this.onAccept,
  });

  final bool isGenerating;
  final bool isAccepting;
  final bool hasDraft;
  final VoidCallback? onGenerate;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    if (hasDraft) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('generate-workout-action'),
              onPressed: onGenerate,
              child: const Text('Regenerate'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton.icon(
              key: const Key('accept-workout-plan-action'),
              onPressed: onAccept,
              icon: isAccepting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(isAccepting ? 'Accepting…' : 'Accept Plan'),
            ),
          ),
        ],
      );
    }

    const label = 'Generate Workout';

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('generate-workout-action'),
        onPressed: onGenerate,
        child: Text(isGenerating ? 'Generating…' : label),
      ),
    );
  }
}
