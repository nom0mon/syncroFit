import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/exercise.dart';
import '../../../shared/widgets/body_silhouette_widget.dart';

/// A single exercise row for the Exercise Library list.
///
/// Displays the exercise name in bold Geist on the left, a subtitle showing
/// muscle group and equipment type at secondary opacity, and a
/// [BodySilhouetteWidget] on the right highlighting the targeted muscles.
///
/// Includes a bottom divider as part of the widget. Tapping the row navigates
/// to the exercise detail screen (or invokes [onTap] if provided).
///
/// No colored badges or Material card wrappers are used (Requirement 3.6).
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({
    super.key,
    required this.exercise,
    this.onTap,
  });

  /// The exercise data to display.
  final Exercise exercise;

  /// Optional tap handler. If null, navigates to the exercise detail screen
  /// via GoRouter.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle();

    return Semantics(
      button: true,
      label: '${exercise.name}, $subtitle',
      child: InkWell(
        onTap: onTap ?? () => context.go('/exercises/${exercise.id}'),
        splashColor: AppColors.pressedOverlay,
        highlightColor: AppColors.pressedOverlay,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.cardBorder,
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              BodySilhouetteWidget(
                targetedMuscleGroups: [exercise.muscleGroup],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the subtitle string as "{muscleGroup} · {equipment}".
  /// If equipment is null or empty, shows muscle group alone.
  String _buildSubtitle() {
    final equipment = exercise.equipment;
    if (equipment == null || equipment.isEmpty) {
      return exercise.muscleGroup;
    }
    return '${exercise.muscleGroup} · $equipment';
  }
}
