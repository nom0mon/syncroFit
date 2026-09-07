import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/exercise.dart';
import '../../../shared/widgets/exercise_media.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/safe_layout.dart';
import '../../exercise_library/providers/exercise_provider.dart';
import '../providers/workout_provider.dart';

/// Displays the currently active exercise as a per-set flow.
class WorkoutActiveScreen extends ConsumerStatefulWidget {
  const WorkoutActiveScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<WorkoutActiveScreen> createState() =>
      _WorkoutActiveScreenState();
}

class _WorkoutActiveScreenState extends ConsumerState<WorkoutActiveScreen> {
  bool _initialized = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWorkout();
    });
  }

  Future<void> _initializeWorkout() async {
    final notifier = ref.read(workoutProvider.notifier);
    _seedExerciseNames(notifier);

    final sessionState = ref.read(workoutProvider);
    if (sessionState.workout == null ||
        sessionState.workout!.id != widget.workoutId) {
      final loaded = await notifier.loadWorkout(widget.workoutId);
      if (!loaded) {
        if (mounted) {
          setState(() {
            _loadError = 'Unable to load this workout. Please try again.';
            _initialized = true;
          });
        }
        return;
      }
      notifier.startWorkout();
    } else if (!sessionState.isInProgress && !sessionState.isCompleted) {
      notifier.startWorkout();
    }

    if (mounted) setState(() => _initialized = true);
  }

  void _seedExerciseNames(WorkoutNotifier notifier) {
    final exercises = ref.read(exerciseProvider).allExercises;
    final map = <int, String>{};
    for (final exercise in exercises) {
      final id = int.tryParse(exercise.id);
      if (id != null) map[id] = exercise.name;
    }
    notifier.setExerciseNames(map);
  }

  Exercise? _currentExerciseDetails() {
    final current = ref.read(workoutProvider).currentExercise;
    if (current == null) return null;
    final exercises = ref.read(exerciseProvider).allExercises;
    for (final exercise in exercises) {
      if (int.tryParse(exercise.id) == current.exerciseId) return exercise;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(workoutProvider);

    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null || sessionState.workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: Center(child: Text(_loadError ?? 'Workout not found.')),
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Exercise ${sessionState.currentExerciseIndex + 1} of ${sessionState.totalExercises}',
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ResponsiveConstrainedPage(
                maxWidth: 720,
                child: SingleChildScrollView(
                  key: const Key('active-workout-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ResponsiveCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sessionState.workout!.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              exerciseName,
                              key: const Key('active-exercise-name'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ExerciseMedia(
                        videoPath: details?.videoPath,
                        // The library can still be loading when a session starts.
                        // Use the resolved workout name so the media and screen
                        // never render as an unnamed exercise.
                        exerciseName: exerciseName,
                        borderRadius: AppSpacing.md,
                      ),
                      const SizedBox(height: AppSpacing.lg),
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
                      _CurrentSetCard(
                        setNumber: sessionState.currentSet,
                        totalSets: currentExercise.sets,
                        perSetLabel: perSetLabel,
                      ),
                      if (details != null &&
                          details.instructions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _ProcedureSection(instructions: details.instructions),
                      ],
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ),
            SafeBottomActionBar(
              avoidKeyboard: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key('finish-set-action'),
                    onPressed: () => _onFinishSet(sessionState.isLastSet),
                    icon: const Icon(Icons.check),
                    label: Text(
                      'Finish Set ${sessionState.currentSet} of ${currentExercise.sets}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    key: const Key('skip-exercise-action'),
                    onPressed: _onSkipExercise,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip Exercise'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onFinishSet(bool _) {
    final notifier = ref.read(workoutProvider.notifier);
    notifier.finishCurrentSet();

    final updated = ref.read(workoutProvider);
    if (updated.isCompleted) {
      context.go('/dashboard/workout/${widget.workoutId}/summary');
    } else if (updated.isResting) {
      context.go('/dashboard/workout/${widget.workoutId}/rest');
    }
  }

  void _onSkipExercise() {
    final notifier = ref.read(workoutProvider.notifier);
    notifier.skipCurrentExercise();

    final updated = ref.read(workoutProvider);
    if (updated.isCompleted) {
      context.go('/dashboard/workout/${widget.workoutId}/summary');
    }
  }
}

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

    return ResponsiveCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      child: Column(
        children: [
          Text(
            'Set $setNumber of $totalSets',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            perSetLabel,
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

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
        for (final entry in instructions.asMap().entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${entry.key + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      entry.value,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
