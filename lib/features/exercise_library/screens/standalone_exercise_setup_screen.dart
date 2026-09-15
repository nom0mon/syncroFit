import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/exercise_illustration.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/exercise_provider.dart';

class StandaloneExerciseSetupScreen extends ConsumerStatefulWidget {
  const StandaloneExerciseSetupScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<StandaloneExerciseSetupScreen> createState() =>
      _StandaloneExerciseSetupScreenState();
}

class _StandaloneExerciseSetupScreenState
    extends ConsumerState<StandaloneExerciseSetupScreen> {
  int sets = 3;
  int reps = 10;
  int durationSeconds = 30;
  int restSeconds = 60;
  bool timed = false;
  bool initialized = false;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseProvider);
    if (library.isLoading) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }
    final exercise = library.allExercises
        .where((item) => item.id == widget.exerciseId)
        .firstOrNull;
    if (exercise == null) {
      return const Scaffold(body: Center(child: Text('Exercise not found.')));
    }
    if (!initialized) {
      timed = exercise.defaultDurationSeconds > 0;
      sets = exercise.defaultSets.clamp(1, 20);
      reps = exercise.defaultReps.clamp(1, 100);
      durationSeconds = exercise.defaultDurationSeconds > 0
          ? exercise.defaultDurationSeconds.clamp(10, 600)
          : 30;
      initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Personalize Exercise')),
      body: ResponsiveConstrainedPage(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            Center(child: ExerciseIllustration(exercise: exercise, size: 160)),
            const SizedBox(height: AppSpacing.md),
            Text(
              exercise.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            _NumberControl(
              label: 'Sets',
              value: sets,
              min: 1,
              max: 20,
              onChanged: (value) => setState(() => sets = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use exercise timer'),
              subtitle: Text(
                timed
                    ? 'Complete each set for a chosen duration'
                    : 'Complete a chosen number of repetitions',
              ),
              value: timed,
              onChanged: (value) => setState(() => timed = value),
            ),
            _NumberControl(
              label: timed ? 'Seconds per set' : 'Repetitions per set',
              value: timed ? durationSeconds : reps,
              min: timed ? 10 : 1,
              max: timed ? 600 : 100,
              step: timed ? 5 : 1,
              onChanged: (value) => setState(() {
                if (timed) {
                  durationSeconds = value;
                } else {
                  reps = value;
                }
              }),
            ),
            _NumberControl(
              label: 'Rest after each set (seconds)',
              value: restSeconds,
              min: 10,
              max: 300,
              step: 5,
              onChanged: (value) => setState(() => restSeconds = value),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => _start(exercise),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Exercise'),
            ),
          ],
        ),
      ),
    );
  }

  void _start(Exercise exercise) {
    final exerciseId = int.tryParse(exercise.id);
    if (exerciseId == null) return;
    final workoutId = 'standalone-${exercise.id}';
    final workout = Workout(
      id: workoutId,
      name: '${exercise.displayName} Session',
      estimatedDurationMinutes: 1,
      isGenerated: false,
      exercises: [
        WorkoutExercise(
          exerciseId: exerciseId,
          sets: sets,
          reps: timed ? 1 : reps,
          durationSeconds: timed ? durationSeconds : 0,
          restSeconds: restSeconds,
          order: 1,
        ),
      ],
    );
    ref.read(workoutProvider.notifier).prepareStandaloneWorkout(
      workout,
      exercise.displayName,
    );
    context.go('/dashboard/workout/$workoutId/active');
  }
}

class _NumberControl extends StatelessWidget {
  const _NumberControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              onPressed: value > min
                  ? () => onChanged((value - step).clamp(min, max))
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 48,
              child: Text('$value', textAlign: TextAlign.center),
            ),
            IconButton(
              onPressed: value < max
                  ? () => onChanged((value + step).clamp(min, max))
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
