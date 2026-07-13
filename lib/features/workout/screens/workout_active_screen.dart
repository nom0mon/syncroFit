import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/enums.dart';
import '../providers/timer_controller.dart';
import '../providers/workout_provider.dart';

/// Displays the currently active exercise with a countdown timer and
/// controls for start, pause, resume, skip, and complete.
///
/// Validates: Requirements 7.2, 7.3, 7.4, 7.5, 7.6, 7.7
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
    // Load the workout and start the session after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWorkout();
    });
  }

  Future<void> _initializeWorkout() async {
    final notifier = ref.read(workoutProvider.notifier);
    final sessionState = ref.read(workoutProvider);

    // Only load if not already loaded or different workout
    if (sessionState.workout == null ||
        sessionState.workout!.id != widget.workoutId) {
      await notifier.loadWorkout(widget.workoutId);
      notifier.startWorkout();
    } else if (!sessionState.isInProgress && !sessionState.isCompleted) {
      notifier.startWorkout();
    }

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(workoutProvider);
    final timerState = ref.watch(timerControllerProvider);

    // Listen for timer completion → navigate to rest or summary
    ref.listen<TimerControllerState>(timerControllerProvider, (prev, next) {
      if (prev?.state != TimerState.completed &&
          next.state == TimerState.completed) {
        _onTimerCompleted();
      }
    });

    if (!_initialized || sessionState.workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If workout is completed, navigate to summary
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Exercise ${sessionState.currentExerciseIndex + 1} of ${sessionState.totalExercises}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const Spacer(),

            // Exercise name
            Text(
              currentExercise.exerciseName,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Sets & reps info
            Text(
              currentExercise.durationSeconds > 0
                  ? '${currentExercise.sets} sets • ${formatDuration(currentExercise.durationSeconds)}'
                  : '${currentExercise.sets} sets • ${currentExercise.reps} reps',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Timer display
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 4,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                formatDuration(timerState.remainingSeconds),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            const Spacer(),

            // Controls
            _buildControls(context, timerState, sessionState),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    TimerControllerState timerState,
    WorkoutSessionState sessionState,
  ) {
    final timerNotifier = ref.read(timerControllerProvider.notifier);
    final currentExercise = sessionState.currentExercise;
    final duration = currentExercise?.durationSeconds ?? 30;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Skip button
        IconButton.filled(
          onPressed: _onSkipPressed,
          icon: const Icon(Icons.skip_next),
          tooltip: 'Skip',
          iconSize: 32,
        ),

        // Start / Pause / Resume button
        if (timerState.state == TimerState.idle ||
            timerState.state == TimerState.completed)
          FilledButton.icon(
            onPressed: () => timerNotifier.start(duration),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          )
        else if (timerState.state == TimerState.running)
          FilledButton.icon(
            onPressed: () => timerNotifier.pause(),
            icon: const Icon(Icons.pause),
            label: const Text('Pause'),
          )
        else if (timerState.state == TimerState.paused)
          FilledButton.icon(
            onPressed: () => timerNotifier.resume(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
          ),

        // Complete button
        IconButton.filled(
          onPressed: _onCompletePressed,
          icon: const Icon(Icons.check),
          tooltip: 'Complete',
          iconSize: 32,
        ),
      ],
    );
  }

  void _onTimerCompleted() {
    final notifier = ref.read(workoutProvider.notifier);

    // Mark exercise as completed
    notifier.completeCurrentExercise();

    // After completing, check if workout is done or go to rest
    final updatedState = ref.read(workoutProvider);
    if (updatedState.isCompleted) {
      context.go('/dashboard/workout/${widget.workoutId}/summary');
    } else {
      context.go('/dashboard/workout/${widget.workoutId}/rest');
    }
  }

  void _onSkipPressed() {
    final sessionState = ref.read(workoutProvider);
    final notifier = ref.read(workoutProvider.notifier);
    final timerNotifier = ref.read(timerControllerProvider.notifier);

    // Reset the timer
    timerNotifier.reset();

    if (sessionState.isLastExercise) {
      // Skip on last exercise → summary
      notifier.skipCurrentExercise();
      context.go('/dashboard/workout/${widget.workoutId}/summary');
    } else {
      // Skip → advance to next exercise
      notifier.skipCurrentExercise();
    }
  }

  void _onCompletePressed() {
    final notifier = ref.read(workoutProvider.notifier);
    final timerNotifier = ref.read(timerControllerProvider.notifier);

    // Reset the timer
    timerNotifier.reset();

    // Complete the current exercise
    notifier.completeCurrentExercise();

    // Navigate based on state
    final updatedState = ref.read(workoutProvider);
    if (updatedState.isCompleted) {
      context.go('/dashboard/workout/${widget.workoutId}/summary');
    } else {
      context.go('/dashboard/workout/${widget.workoutId}/rest');
    }
  }
}
