import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/workout_history.dart';
import '../../../shared/widgets/section_header.dart';
import '../utils/weekly_load_utils.dart';

/// A bar chart widget that renders weekly workout completion counts across
/// the last [weekCount] rolling ISO (Monday-anchored) weeks.
///
/// Key behaviours:
///  • X-axis flows left → right, oldest week on the far left, current week
///    on the far right.
///  • Missing weeks are zero-filled so the timeline is always continuous.
///  • A dashed horizontal goal line marks the user's [weeklyGoal] target.
///  • The Y-axis maximum is set to `max(actualMax, weeklyGoal) + 1` so the
///    goal line is always visible even when no week has reached it yet.
class WeeklyLoadChartWidget extends StatelessWidget {
  const WeeklyLoadChartWidget({
    super.key,
    required this.sessions,
    this.referenceDate,
    this.weeklyGoal = 4,
    this.weekCount = 6,
    this.maxChartHeight = 140,
    this.barWidth = 18,
  });

  /// Raw workout history records used to derive per-week counts.
  final List<WorkoutHistory> sessions;

  /// Reference date for the rolling window. Defaults to [DateTime.now()].
  final DateTime? referenceDate;

  /// Weekly workout target shown as a dashed goal line on the chart.
  final int weeklyGoal;

  /// Number of rolling weeks to display (e.g. 6 = last 6 weeks including
  /// the current week).
  final int weekCount;

  /// Pixel height allocated to the tallest possible bar.
  final double maxChartHeight;

  /// Width of each bar in logical pixels.
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final now = referenceDate ?? DateTime.now();
    final theme = Theme.of(context);

    // Build the continuous, chronologically-sorted data series.
    final dataPoints = buildWeeklyCompletionData(
      sessions: sessions,
      referenceDate: now,
      weekCount: weekCount,
    );

    final counts = dataPoints.map((p) => p.count).toList();
    final maxCount = counts.fold<int>(0, (m, c) => c > m ? c : m);

    // Y-axis ceiling: always high enough to show the goal line clearly.
    final yMax = (maxCount > weeklyGoal ? maxCount : weeklyGoal) + 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'WEEKLY STATISTICS',
          trailingLabel: '[LAST 6 WEEKS]',
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Weekly goal: $weeklyGoal workouts',
          style: AppTextStyles.caption.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: maxChartHeight + AppSpacing.xxl,
          child: BarChart(
            _buildChartData(dataPoints, counts, yMax, theme),
            duration: Duration.zero,
          ),
        ),
      ],
    );
  }

  BarChartData _buildChartData(
    List<WeeklyDataPoint> dataPoints,
    List<int> counts,
    double yMax,
    ThemeData theme,
  ) {
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.25);
    final goalLineColor = theme.colorScheme.primary.withValues(alpha: 0.55);
    final labelColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return BarChartData(
      maxY: yMax,
      minY: 0,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(enabled: false),

      // ── Dashed goal line ───────────────────────────────────────────────────
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: weeklyGoal.toDouble(),
            color: goalLineColor,
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              style: AppTextStyles.caption.copyWith(
                color: goalLineColor,
                fontWeight: FontWeight.w600,
              ),
              labelResolver: (_) => 'Goal',
            ),
          ),
        ],
      ),

      // ── Axis labels ────────────────────────────────────────────────────────
      titlesData: FlTitlesData(
        show: true,
        // Count label above each bar.
        topTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= counts.length) {
                return const SizedBox.shrink();
              }
              final label = counts[index] > 0 ? '${counts[index]}' : '';
              return Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
        // "MMM d" week-start date on the X-axis.
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= dataPoints.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  dataPoints[index].label,
                  style: AppTextStyles.caption.copyWith(color: labelColor),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              );
            },
          ),
        ),
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),

      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),

      // ── Bars ───────────────────────────────────────────────────────────────
      barGroups: List.generate(dataPoints.length, (index) {
        final count = counts[index];
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              // Use the raw count as the bar value so the Y-axis scale is
              // meaningful (workouts completed, not a scaled pixel height).
              toY: count.toDouble(),
              // Render zero-count bars as a thin stub so the column is still
              // visually present, making the gap immediately apparent.
              width: barWidth,
              color: count > 0 ? activeColor : inactiveColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        );
      }),
    );
  }
}
