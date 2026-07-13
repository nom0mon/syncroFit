import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/enums.dart';
import '../providers/timer_controller.dart';
import '../providers/workout_provider.dart';

/// Displays a rest timer countdown between exercises.
///
/// The rest duration is configurable per exercise (10-120 seconds, default 30).
/// The user can skip the rest to advance immediately.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRestTimer();
    });
  }

  void _startRestTimer() {
    final sessionState = ref.read(workoutProvider);
    final restSeconds = sessionState.currentRestSeconds;
    final restTimerNotifier = ref.read(restTimerControllerProvider.notifier);

    restTimerNotifier.start(restSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restTimerState = ref.watch(restTimerControllerProvider);
    final sessionState = ref.watch(workoutProvider);

    // Listen for rest timer completion → advance to next exercise
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
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const Spacer(),

            // Rest label
            Text(
              'Rest Time',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Timer circle
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.tertiary,
                  width: 4,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                formatDuration(restTimerState.remainingSeconds),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Next exercise info
            if (sessionState.currentExercise != null) ...[
              Text(
                'Up Next',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _getNextExerciseName(sessionState),
                style: theme.textTheme.titleLarge,
              ),
            ],

            const Spacer(),

            // Skip button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _onSkipRest,
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip Rest'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  String _getNextExerciseName(WorkoutSessionState sessionState) {
    final workout = sessionState.workout;
    if (workout == null) return '';
    final nextIndex = sessionState.currentExerciseIndex + 1;
    if (nextIndex >= workout.exercises.length) return '';
    return workout.exercises[nextIndex].exerciseName;
  }

  void _onRestComplete() {
    final notifier = ref.read(workoutProvider.notifier);
    notifier.advanceToNextExercise();
    context.go('/dashboard/workout/${widget.workoutId}/active');
  }

  void _onSkipRest() {
    final restTimerNotifier = ref.read(restTimerControllerProvider.notifier);
    final notifier = ref.read(workoutProvider.notifier);

    // Cancel rest timer
    restTimerNotifier.reset();

    // Advance to next exercise
    notifier.skipRest();
    context.go('/dashboard/workout/${widget.workoutId}/active');
  }
}
