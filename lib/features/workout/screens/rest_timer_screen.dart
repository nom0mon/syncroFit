import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/safe_layout.dart';
import '../../exercise_library/providers/exercise_provider.dart';
import '../providers/timer_controller.dart';
import '../providers/workout_provider.dart';

/// Displays a rest timer countdown between exercises.
///
/// Validates: Requirements 7.7, 7.8
class RestTimerScreen extends ConsumerStatefulWidget {
  const RestTimerScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends ConsumerState<RestTimerScreen> {
  @override
  void initState() {
    super.initState();
    // Riverpod forbids mutating a provider during initState. Start as soon as
    // the first frame is built; the UI below supplies the prescribed value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startRestTimer();
    });
  }

  void _startRestTimer() {
    final restSeconds = ref.read(workoutProvider).currentRestSeconds;
    ref.read(restTimerControllerProvider.notifier).start(restSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restTimerState = ref.watch(restTimerControllerProvider);
    final sessionState = ref.watch(workoutProvider);
    final visibleRemainingSeconds = restTimerState.state == TimerState.idle
        ? sessionState.currentRestSeconds
        : restTimerState.remainingSeconds;

    ref.listen<TimerControllerState>(restTimerControllerProvider, (prev, next) {
      if (prev?.state != TimerState.completed &&
          next.state == TimerState.completed) {
        _onRestComplete();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rest'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ResponsiveConstrainedPage(
                maxWidth: 560,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      key: const Key('rest-timer-scroll'),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0,
                            constraints.maxHeight - (AppSpacing.md * 2),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                      Text(
                        'Rest Time',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _RestTimerCircle(
                        remainingSeconds: visibleRemainingSeconds,
                      ),
                      if (sessionState.currentExercise != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Up Next',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _getNextActivity(sessionState),
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeBottomActionBar(
              avoidKeyboard: false,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('skip-rest-action'),
                  onPressed: _onSkipRest,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip Rest'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNextActivity(WorkoutSessionState sessionState) {
    final workout = sessionState.workout;
    if (workout == null) return '';

    final current = sessionState.currentExercise;
    if (current != null && !sessionState.isLastSet) {
      return 'Set ${sessionState.currentSet + 1} of ${current.sets}';
    }

    final nextIndex = sessionState.currentExerciseIndex + 1;
    if (nextIndex >= workout.exercises.length) return '';

    final nextExercise = workout.exercises[nextIndex];
    final exercises = ref.read(exerciseProvider).allExercises;
    for (final exercise in exercises) {
      if (int.tryParse(exercise.id) == nextExercise.exerciseId) {
        return exercise.name;
      }
    }
    return 'Exercise ${nextExercise.exerciseId}';
  }

  void _onRestComplete() {
    ref.read(workoutProvider.notifier).completeRest();
    context.go('/dashboard/workout/${widget.workoutId}/active');
  }

  void _onSkipRest() {
    ref.read(restTimerControllerProvider.notifier).reset();
    ref.read(workoutProvider.notifier).skipRest();
    context.go('/dashboard/workout/${widget.workoutId}/active');
  }
}

class _RestTimerCircle extends StatelessWidget {
  const _RestTimerCircle({required this.remainingSeconds});

  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.tertiary,
              width: 4,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatDuration(remainingSeconds),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.tertiary,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
