import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/workout_history.dart';
import '../../../shared/widgets/section_header.dart';
import '../utils/session_display_utils.dart';

/// Displays completed workout sessions for a selected date.
///
/// Shows a [SectionHeader] with "COMPLETED SESSIONS" title and a count label,
/// the formatted selected date, and either an empty-state message or a list
/// of session summary rows (workout name + duration).
class CompletedSessionsWidget extends StatelessWidget {
  const CompletedSessionsWidget({
    super.key,
    required this.sessions,
    required this.selectedDate,
  });

  /// The workout sessions completed on [selectedDate].
  final List<WorkoutHistory> sessions;

  /// The currently selected date to display sessions for.
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'COMPLETED SESSIONS',
          trailingLabel: '${sessions.length} ON DAY',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          formatDateDisplay(selectedDate),
          style: AppTextStyles.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (sessions.isEmpty)
          _buildEmptyState(theme)
        else
          _buildSessionList(theme),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Opacity(
      opacity: 0.6,
      child: Text(
        'No finished workouts landed on this day yet. '
        'Pick another date or log a new session.',
        style: AppTextStyles.bodySmall.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSessionList(ThemeData theme) {
    return Column(
      children:
          sessions.map((session) => _buildSessionRow(session, theme)).toList(),
    );
  }

  Widget _buildSessionRow(WorkoutHistory session, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              session.workoutName,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatDuration(session.totalDurationSeconds),
            style: AppTextStyles.bodyMedium.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
