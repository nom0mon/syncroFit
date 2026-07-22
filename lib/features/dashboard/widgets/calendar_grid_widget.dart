import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../utils/calendar_utils.dart';

/// A monthly calendar grid widget that shows workout completion status per day.
///
/// Renders a section header ("CALENDAR GRID" / "[TAP A DAY]"), weekday headers,
/// and a date grid with visual indicators:
/// - White filled circle for completed dates
/// - White outlined circle for today (no workout)
/// - No decoration for other dates
///
/// Emits selected date via [onDateSelected] callback.
/// Defaults to today on first display.
class CalendarGridWidget extends StatelessWidget {
  const CalendarGridWidget({
    super.key,
    required this.completedDates,
    required this.selectedDate,
    required this.onDateSelected,
    this.year,
    this.month,
  });

  /// Dates with completed workouts.
  final Set<DateTime> completedDates;

  /// Currently selected date (highlighted in the grid).
  final DateTime selectedDate;

  /// Callback when a date is tapped.
  final ValueChanged<DateTime> onDateSelected;

  /// Year to display. Defaults to current year if null.
  final int? year;

  /// Month to display. Defaults to current month if null.
  final int? month;

  static const _weekdayHeaders = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final displayYear = year ?? now.year;
    final displayMonth = month ?? now.month;
    final grid = generateCalendarGrid(displayYear, displayMonth);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'CALENDAR GRID',
          trailingLabel: '[TAP A DAY]',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildWeekdayHeaders(theme),
        const SizedBox(height: AppSpacing.xs),
        _buildDateGrid(grid, displayYear, displayMonth, theme),
      ],
    );
  }

  Widget _buildWeekdayHeaders(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _weekdayHeaders.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: AppTextStyles.labelSmall.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateGrid(List<int?> grid, int displayYear, int displayMonth, ThemeData theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: grid.length,
      itemBuilder: (context, index) {
        final day = grid[index];

        if (day == null) {
          return const SizedBox.shrink();
        }

        final date = DateTime(displayYear, displayMonth, day);
        final status = getDayStatus(date, completedDates);

        return GestureDetector(
          onTap: () => onDateSelected(date),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: _buildDayCell(day, status, theme),
          ),
        );
      },
    );
  }

  Widget _buildDayCell(int day, DayStatus status, ThemeData theme) {
    const cellSize = 32.0;
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;

    switch (status) {
      case DayStatus.completed:
        // Filled circle with inverted colors
        return Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: onSurface,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: AppTextStyles.bodySmall.copyWith(
              color: surface,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case DayStatus.today:
        // Outlined circle
        return Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: onSurface,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: AppTextStyles.bodySmall.copyWith(
              color: onSurface,
            ),
          ),
        );
      case DayStatus.normal:
        // No decoration
        return Text(
          '$day',
          style: AppTextStyles.bodySmall.copyWith(
            color: onSurface,
          ),
        );
    }
  }
}
