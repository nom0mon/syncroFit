import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../utils/calendar_utils.dart';

/// A monthly calendar grid widget that shows workout schedule and completion.
///
/// Renders a section header ("CALENDAR GRID" / "[TAP A DAY]"), weekday headers,
/// and a date grid with visual indicators:
/// - Outlined circle for dates whose weekday has a scheduled workout
/// - Filled circle for the currently selected date
/// - Small dot for completed dates
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
    this.scheduledWeekdays = const {},
    this.year,
    this.month,
  });

  /// Dates with completed workouts.
  final Set<DateTime> completedDates;

  /// Currently selected date (highlighted in the grid).
  final DateTime selectedDate;

  /// Callback when a date is tapped.
  final ValueChanged<DateTime> onDateSelected;

  /// ISO weekdays (Monday = 1, Sunday = 7) that have a recurring workout.
  final Set<int> scheduledWeekdays;

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

  Widget _buildDateGrid(
    List<int?> grid,
    int displayYear,
    int displayMonth,
    ThemeData theme,
  ) {
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

        final isSelected = _isSameDay(date, selectedDate);
        final hasSchedule = scheduledWeekdays.contains(date.weekday);
        return Semantics(
          button: true,
          selected: isSelected,
          label: 'Select ${date.year}-${date.month}-${date.day}',
          child: GestureDetector(
            onTap: () => onDateSelected(date),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: _buildDayCell(day, status, isSelected, hasSchedule, theme),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayCell(
    int day,
    DayStatus status,
    bool isSelected,
    bool hasSchedule,
    ThemeData theme,
  ) {
    const cellSize = 36.0;
    final onSurface = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final completed = status == DayStatus.completed;
    final today = status == DayStatus.today;

    return SizedBox.square(
      dimension: cellSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSelected || hasSchedule)
            Container(
              key: ValueKey('calendar-indicator-$day'),
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: isSelected ? onSurface : Colors.transparent,
                shape: BoxShape.circle,
                border: hasSchedule && !isSelected
                    ? Border.all(color: onSurface, width: 1.5)
                    : null,
              ),
            ),
          Text(
            '$day',
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? surface : onSurface,
              fontWeight:
                  today || isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          if (completed && !isSelected)
            Positioned(
              bottom: 1,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
