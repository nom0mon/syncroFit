import 'package:flutter/material.dart';

import '../models/exercise.dart';

/// Offline exercise artwork sourced from Workout Guide (CC BY-SA 4.0).
/// Only exact movement/equipment matches are mapped to avoid teaching an
/// incorrect form. Unmatched exercises receive an explicit target fallback.
class ExerciseIllustration extends StatelessWidget {
  const ExerciseIllustration({
    super.key,
    required this.exercise,
    this.size = 72,
  });

  final Exercise exercise;
  final double size;

  static const Map<String, String> _assetByExercise = {
    'push-up': 'push-up',
    'dumbbell bench press': 'dumbbell-bench-press',
    'barbell bench press': 'bench-press',
    'cable chest fly': 'cable-fly',
    'pull-up': 'pull-up',
    'barbell bent-over row': 'barbell-row',
    'dumbbell single-arm row': 'one-arm-dumbbell-row',
    'resistance band pull-apart': 'band-pull-apart',
    'dumbbell overhead press': 'standing-dumbbell-press',
    'pike push-up': 'pike-push-up',
    'kettlebell press': 'repdb-double-kettlebell-overhead-press.webp',
    'dumbbell bicep curl': 'bicep-curl',
    'barbell curl': 'repdb-barbell-curl.webp',
    'chin-up': 'chin-up',
    'resistance band curl': 'bicep-curl',
    'tricep dip': 'dip',
    'dumbbell overhead tricep extension': 'dumbbell-overhead-tricep-extension',
    'cable tricep pushdown': 'tricep-pushdown',
    'bodyweight squat': 'bodyweight-squat',
    'barbell back squat': 'squat',
    'kettlebell goblet squat': 'goblet-squat',
    'leg press': 'leg-press',
    'dumbbell romanian deadlift': 'dumbbell-romanian-deadlift',
    'plank': 'plank',
    'hanging leg raise': 'hanging-leg-raise',
    'kettlebell russian twist': 'repdb-kettlebell-russian-twist.webp',
    'cable woodchop': 'cable-woodchop',
    'burpee': 'burpee',
    'kettlebell swing': 'kettlebell-swing',
    'barbell deadlift': 'deadlift',
    'resistance band thruster': 'repdb-thruster.webp',
    'dumbbell clean and press': 'repdb-double-kettlebell-clean-and-press.webp',
    'resistance band lateral raise': 'lateral-raise',
    'close-grip barbell bench press': 'close-grip-bench-press',
    'walking lunge': 'walking-lunge',
    'mountain climber': 'mountain-climber',
    'jumping jack': 'jumping-jack',
    'high knees': 'high-knees',
    'broad jump': 'broad-jump',
  };

  static bool hasIllustrationForName(String name) =>
      _assetByExercise.containsKey(name.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final slug = _assetByExercise[exercise.name.trim().toLowerCase()];
    final semantics = slug == null
        ? '${exercise.displayMuscleGroup} target indicator'
        : '${exercise.displayName} starting-position illustration';

    return Semantics(
      image: true,
      label: semantics,
      child: SizedBox.square(
        dimension: size,
        child: slug == null
            ? _TargetFallback(exercise: exercise)
            : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Image.asset(
                    'assets/exercise_illustrations/'
                    '${slug.endsWith('.webp') ? slug : '$slug.png'}',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _TargetFallback(exercise: exercise),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TargetFallback extends StatelessWidget {
  const _TargetFallback({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.track_changes, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 2),
          Text(
            exercise.displayMuscleGroup,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
