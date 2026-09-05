import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/exercise.dart';
import '../../../shared/widgets/exercise_media.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/exercise_provider.dart';

/// Displays responsive details for a single exercise.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseProvider);
    final exercise =
        state.allExercises.where((e) => e.id == exerciseId).firstOrNull;

    if (state.isLoading) {
      return const Scaffold(body: LoadingIndicator());
    }

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise Detail')),
        body: const Center(
          child: Text('Exercise not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          exercise.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _ExerciseDetailContent(exercise: exercise),
    );
  }
}

class _ExerciseDetailContent extends StatelessWidget {
  const _ExerciseDetailContent({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ResponsiveConstrainedPage(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: AdaptiveGridList(
            minItemWidth: 320,
            maxColumns: 2,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              ExerciseMedia(
                videoPath: exercise.videoPath,
                exerciseName: exercise.name,
              ),
              _ExerciseInformation(exercise: exercise),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseInformation extends StatelessWidget {
  const _ExerciseInformation({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const Key('exercise-information'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.name,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      Icons.track_changes,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const WidgetSpan(child: SizedBox(width: AppSpacing.xs)),
                  TextSpan(text: exercise.muscleGroup),
                ],
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            _DifficultyChip(difficulty: exercise.difficulty),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _EquipmentSection(equipment: exercise.equipment),
        const SizedBox(height: AppSpacing.lg),
        _InstructionsSection(instructions: exercise.instructions),
      ],
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});

  final DifficultyLevel difficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _difficultyColor(difficulty);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _difficultyLabel(difficulty),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EquipmentSection extends StatelessWidget {
  const _EquipmentSection({required this.equipment});

  final String? equipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEquipment = equipment != null && equipment!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasEquipment
                  ? Icons.inventory_2_outlined
                  : Icons.check_circle_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                hasEquipment ? equipment! : 'No equipment',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InstructionsSection extends StatelessWidget {
  const _InstructionsSection({required this.instructions});

  final List<String> instructions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instructions',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (instructions.isEmpty)
          Text(
            'No instructions available',
            style: theme.textTheme.bodyMedium,
          )
        else
          ...instructions.asMap().entries.map((entry) {
            final stepNumber = entry.key + 1;
            final instruction = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$stepNumber',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        instruction,
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

String _difficultyLabel(DifficultyLevel level) {
  return switch (level) {
    DifficultyLevel.beginner => 'Beginner',
    DifficultyLevel.intermediate => 'Intermediate',
    DifficultyLevel.advanced => 'Advanced',
  };
}

Color _difficultyColor(DifficultyLevel level) {
  return switch (level) {
    DifficultyLevel.beginner => AppColors.successGreen,
    DifficultyLevel.intermediate => AppColors.warningOrange,
    DifficultyLevel.advanced => AppColors.errorRed,
  };
}
