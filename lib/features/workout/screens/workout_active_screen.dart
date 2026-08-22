import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/exercise.dart';
import '../../exercise_library/providers/exercise_provider.dart';
import '../providers/workout_provider.dart';

/// Displays the currently active exercise as a per-set flow.
///
/// Each set is shown one at a time (e.g. "Set 1 · 6 reps") with a single
/// "Finish Set" button. There is no start button and no exercise countdown
/// timer — the user simply performs the set and taps finish. After the last
/// set of an exercise, the rest timer applies before the next exercise.
///
/// The screen also surfaces the exercise procedure (instructions) and a
/// video guide area (placeholder until real videos are added).
class WorkoutActiveScreen extends ConsumerStatefulWidget {
  const WorkoutActiveScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<WorkoutActiveScreen> createState() =>
      _WorkoutActiveScreenState();
}

class _WorkoutActiveScreenState extends ConsumerState<WorkoutActiveScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWorkout();
    });
  }

  Future<void> _initializeWorkout() async {
    final notifier = ref.read(workoutProvider.notifier);
    final sessionState = ref.read(workoutProvider);

    // Provide exercise-name resolution so real names show instead of ids.
    _seedExerciseNames(notifier);

    if (sessionState.workout == null ||
        sessionState.workout!.id != widget.workoutId) {
      await notifier.loadWorkout(widget.workoutId);
      notifier.startWorkout();
    } else if (!sessionState.isInProgress && !sessionState.isCompleted) {
      notifier.startWorkout();
    }

    if (mounted) setState(() => _initialized = true);
  }

  /// Builds a map of exercise id → name from the loaded exercise library and
  /// hands it to the workout notifier for name resolution.
  void _seedExerciseNames(WorkoutNotifier notifier) {
    final exercises = ref.read(exerciseProvider).allExercises;
    final map = <int, String>{};
    for (final e in exercises) {
      final id = int.tryParse(e.id);
      if (id != null) map[id] = e.name;
    }
    notifier.setExerciseNames(map);
  }

  /// Looks up the full [Exercise] record for the current workout exercise.
  Exercise? _currentExerciseDetails() {
    final sessionState = ref.read(workoutProvider);
    final current = sessionState.currentExercise;
    if (current == null) return null;
    final exercises = ref.read(exerciseProvider).allExercises;
    for (final e in exercises) {
      if (int.tryParse(e.id) == current.exerciseId) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(workoutProvider);

    if (!_initialized || sessionState.workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (sessionState.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/dashboard/workout/${widget.workoutId}/summary');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentExercise = sessionState.currentExercise;
    if (currentExercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: Text('No exercise available')),
      );
    }

    final theme = Theme.of(context);
    final notifier = ref.read(workoutProvider.notifier);
    final details = _currentExerciseDetails();
    final exerciseName = details?.name ?? notifier.nameFor(currentExercise);

    final isDuration = currentExercise.durationSeconds > 0;
    final perSetLabel = isDuration
        ? formatDuration(currentExercise.durationSeconds)
        : '${currentExercise.reps} reps';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Exercise ${sessionState.currentExerciseIndex + 1} of ${sessionState.totalExercises}',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Video guide area (placeholder until real videos exist).
                    _VideoGuide(videoPath: details?.videoPath),
                    const SizedBox(height: AppSpacing.lg),

                    // Exercise name.
                    Text(
                      exerciseName,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Overall sets summary.
                    Text(
                      isDuration
                          ? '${currentExercise.sets} sets · ${formatDuration(currentExercise.durationSeconds)}'
                          : '${currentExercise.sets} sets · ${currentExercise.reps} reps',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Current set card.
                    _CurrentSetCard(
                      setNumber: sessionState.currentSet,
                      totalSets: currentExercise.sets,
                      perSetLabel: perSetLabel,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Procedure / instructions.
                    if (details != null && details.instructions.isNotEmpty)
                      _ProcedureSection(instructions: details.instructions),

                    const SizedBox(height: AppSpacing.xl),

                    // Finish set button + skip. There is no "Start" — the
                    // user performs the set then taps finish.
                    FilledButton.icon(
                      onPressed: () => _onFinishSet(sessionState.isLastSet),
                      icon: const Icon(Icons.check),
                      label: Text(
                        'Finish Set ${sessionState.currentSet} of ${currentExercise.sets}',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: _onSkipExercise,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Skip Exercise'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onFinishSet(bool wasLastSet) {
    final notifier = ref.read(workoutProvider.notifier);
    notifier.finishCurrentSet();

    final updated = ref.read(workoutProvider);
    if (updated.isCompleted) {
      context.go('/dashboard/workout/${widget.workoutId}/summary');
    } else if (updated.isResting) {
      // Finished the last set of this exercise → rest before the next one.
      context.go('/dashboard/workout/${widget.workoutId}/rest');
    }
    // Otherwise we simply advanced to the next set — stay on this screen.
  }

  void _onSkipExercise() {
    final notifier = ref.read(workoutProvider.notifier);
    notifier.skipCurrentExercise();

    final updated = ref.read(workoutProvider);
    if (updated.isCompleted) {
      context.go('/dashboard/workout/${widget.workoutId}/summary');
    }
    // Otherwise the notifier advanced to the next exercise (set reset to 1).
  }
}

/// Card showing the current set and its rep/duration target.
class _CurrentSetCard extends StatelessWidget {
  const _CurrentSetCard({
    required this.setNumber,
    required this.totalSets,
    required this.perSetLabel,
  });

  final int setNumber;
  final int totalSets;
  final String perSetLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        child: Column(
          children: [
            Text(
              'Set $setNumber of $totalSets',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              perSetLabel,
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Video guide area. Shows a play placeholder until real videos are available.
class _VideoGuide extends StatelessWidget {
  const _VideoGuide({this.videoPath});

  final String? videoPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Video guide coming soon',
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

/// Numbered procedure/instructions for the current exercise.
class _ProcedureSection extends StatelessWidget {
  const _ProcedureSection({required this.instructions});

  final List<String> instructions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to perform',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...instructions.asMap().entries.map((entry) {
          final step = entry.key + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$step',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      entry.value,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
