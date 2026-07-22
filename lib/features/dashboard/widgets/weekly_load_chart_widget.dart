import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/workout_session.dart';
import '../../../shared/widgets/section_header.dart';
import '../utils/weekly_load_utils.dart';

/// A widget that renders a 4-bar vertical bar chart showing training volume
/// across the last 4 weeks (W1–W4).
///
/// White bars indicate weeks with at least one session; grey bars indicate
/// weeks with zero volume. The numeric volume value is displayed above each bar.
class WeeklyLoadChartWidget extends StatelessWidget {
  const WeeklyLoadChartWidget({
    super.key,
    required this.sessions,
    this.referenceDate,
    this.maxChartHeight = 120,
    this.barWidth = 20,
  });

  /// The workout sessions used to calculate weekly volumes.
  final List<WorkoutSession> sessions;

  /// Reference date for computing week ranges. Defaults to [DateTime.now()].
  final DateTime? referenceDate;

  /// Maximum height for the tallest bar in the chart.
  final double maxChartHeight;

  /// Width of each bar in the chart.
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final ref = referenceDate ?? DateTime.now();
    final weekRanges = computeWeekRanges(ref);
    final theme = Theme.of(context);

    // Calculate volumes for each week.
    final volumes = weekRanges
        .map((range) => calculateWeeklyVolume(sessions, range.start))
        .toList();

    // Compute proportional bar heights.
    final barHeights = computeBarHeights(volumes, maxChartHeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'WEEKLY LOAD',
          trailingLabel: '[LAST 4]',
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: maxChartHeight + AppSpacing.xxl,
          child: BarChart(
            _buildChartData(volumes, barHeights, theme),
            duration: Duration.zero,
          ),
        ),
      ],
    );
  }

  BarChartData _buildChartData(List<int> volumes, List<double> barHeights, ThemeData theme) {
    final maxY = barHeights.isEmpty
        ? maxChartHeight
        : barHeights.reduce((a, b) => a > b ? a : b);

    return BarChartData(
      maxY: maxY > 0 ? maxY : maxChartHeight,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(enabled: false),
      titlesData: FlTitlesData(
        show: true,
        topTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= volumes.length) {
                return const SizedBox.shrink();
              }
              return Text(
                '${volumes[index]}',
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              );
            },
            reservedSize: 20,
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index > 3) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'W${index + 1}',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              );
            },
            reservedSize: 24,
          ),
        ),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(4, (index) {
        final volume = index < volumes.length ? volumes[index] : 0;
        final height = index < barHeights.length ? barHeights[index] : 4.0;
        final isZero = volume == 0;

        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: height,
              width: barWidth,
              color: isZero
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface,
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
