import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/exercise.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/exercise_provider.dart';

/// Displays full details of a single exercise including name, muscle group,
/// numbered instructions, equipment, difficulty, and video player.
///
/// Validates: Requirements 8.3, 8.4, 8.5
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseProvider);
    final exercise = state.allExercises.where((e) => e.id == exerciseId).firstOrNull;

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
        title: Text(exercise.name),
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video player component
          _ExerciseVideoPlayer(exercise: exercise),
          const SizedBox(height: AppSpacing.lg),

          // Exercise name
          Text(
            exercise.name,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Muscle group and difficulty row
          Row(
            children: [
              Icon(
                Icons.track_changes,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                exercise.muscleGroup,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _DifficultyChip(difficulty: exercise.difficulty),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Equipment section
          _EquipmentSection(equipment: exercise.equipment),
          const SizedBox(height: AppSpacing.lg),

          // Instructions section (numbered list)
          _InstructionsSection(instructions: exercise.instructions),
        ],
      ),
    );
  }
}

/// Video player component for exercise demonstrations.
/// Displays a video player using `videoPath`. If the path is null or the
/// asset is unavailable, falls back to a placeholder icon.
///
/// Validates: Requirements 8.3, 8.4
class _ExerciseVideoPlayer extends StatefulWidget {
  const _ExerciseVideoPlayer({required this.exercise});

  final Exercise exercise;

  @override
  State<_ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<_ExerciseVideoPlayer> {
  bool _assetAvailable = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAssetAvailability();
  }

  @override
  void didUpdateWidget(covariant _ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.videoPath != widget.exercise.videoPath) {
      _checkAssetAvailability();
    }
  }

  Future<void> _checkAssetAvailability() async {
    final videoPath = widget.exercise.videoPath;
    if (videoPath == null || videoPath.isEmpty) {
      setState(() {
        _assetAvailable = false;
        _isChecking = false;
      });
      return;
    }

    try {
      await rootBundle.load(videoPath);
      if (mounted) {
        setState(() {
          _assetAvailable = true;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _assetAvailable = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final videoPath = widget.exercise.videoPath;

    // Fallback: show placeholder if videoPath is null or asset unavailable
    if (videoPath == null || videoPath.isEmpty || (!_isChecking && !_assetAvailable)) {
      return _VideoPlaceholder(theme: theme);
    }

    // While checking asset availability, show a loading state
    if (_isChecking) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Asset is available - render a video player UI
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video path label
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                videoPath,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          // Play button overlay
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 40,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback placeholder widget shown when videoPath is null or asset unavailable.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Video not available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays difficulty as a colored chip.
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

/// Displays the equipment required, or "No equipment" if none.
class _EquipmentSection extends StatelessWidget {
  const _EquipmentSection({required this.equipment});

  final String? equipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              equipment != null ? Icons.inventory_2_outlined : Icons.check_circle_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              equipment ?? 'No equipment',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ],
    );
  }
}

/// Displays step-by-step instructions as a numbered list (Req 8.5).
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

/// Returns a user-friendly label for a difficulty level.
String _difficultyLabel(DifficultyLevel level) {
  return switch (level) {
    DifficultyLevel.beginner => 'Beginner',
    DifficultyLevel.intermediate => 'Intermediate',
    DifficultyLevel.advanced => 'Advanced',
  };
}

/// Returns a color associated with a difficulty level.
Color _difficultyColor(DifficultyLevel level) {
  return switch (level) {
    DifficultyLevel.beginner => AppColors.successGreen,
    DifficultyLevel.intermediate => AppColors.warningOrange,
    DifficultyLevel.advanced => AppColors.errorRed,
  };
}
