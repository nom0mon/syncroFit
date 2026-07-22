import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/edge_fade_gradient.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/progress_provider.dart';

/// Displays progress summary with stats, charts, and recent workout history.
///
/// Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.6
class ProgressSummaryScreen extends ConsumerWidget {
  const ProgressSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: progressAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.invalidate(progressProvider),
        ),
        data: (state) => _ProgressContent(state: state),
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrollable content
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryStats(state: state),
              const SizedBox(height: AppSpacing.lg),
              _WeightHistoryChart(data: state.weightHistory),
              const SizedBox(height: AppSpacing.lg),
              _BmiHistoryChart(data: state.bmiHistory),
              const SizedBox(height: AppSpacing.lg),
              _WeeklyStatsChart(data: state.weeklyStats),
              const SizedBox(height: AppSpacing.lg),
              _RecentWorkouts(sessions: state.recentSessions),
            ],
          ),
        ),
        // Top edge fade gradient
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: EdgeFadeGradient(isTop: true),
        ),
        // Bottom edge fade gradient
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: EdgeFadeGradient(isTop: false),
        ),
      ],
    );
  }
}

/// Displays summary stat cards: total workouts, current streak, longest streak, current weight.
class _SummaryStats extends StatelessWidget {
  const _SummaryStats({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Summary', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.6,
          children: [
            _StatCard(
              label: 'Total Workouts',
              value: '${state.totalWorkouts}',
              icon: Icons.fitness_center,
            ),
            _StatCard(
              label: 'Current Streak',
              value: '${state.currentStreak} days',
              icon: Icons.local_fire_department,
            ),
            _StatCard(
              label: 'Longest Streak',
              value: '${state.longestStreak} days',
              icon: Icons.emoji_events,
            ),
            _StatCard(
              label: 'Current Weight',
              value: '${state.currentWeightKg.toStringAsFixed(1)} kg',
              icon: Icons.monitor_weight,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Line chart for weight history over time.
class _WeightHistoryChart extends StatelessWidget {
  const _WeightHistoryChart({required this.data});

  final List<WeightDataPoint> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weightKg);
    }).toList();

    final minY = data.map((d) => d.weightKg).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = data.map((d) => d.weightKg).reduce((a, b) => a > b ? a : b) + 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weight History', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Date',
                    style: theme.textTheme.bodySmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      // Show labels at reasonable intervals
                      if (data.length > 5 && index % 2 != 0) {
                        return const SizedBox.shrink();
                      }
                      final date = data[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    'kg',
                    style: theme.textTheme.bodySmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: theme.colorScheme.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Line chart for BMI history over time.
class _BmiHistoryChart extends StatelessWidget {
  const _BmiHistoryChart({required this.data});

  final List<BmiDataPoint> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.bmi);
    }).toList();

    final minY = data.map((d) => d.bmi).reduce((a, b) => a < b ? a : b) - 1;
    final maxY = data.map((d) => d.bmi).reduce((a, b) => a > b ? a : b) + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BMI History', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Date',
                    style: theme.textTheme.bodySmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      if (data.length > 5 && index % 2 != 0) {
                        return const SizedBox.shrink();
                      }
                      final date = data[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    'BMI',
                    style: theme.textTheme.bodySmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: theme.colorScheme.secondary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bar chart for weekly workout statistics.
class _WeeklyStatsChart extends StatelessWidget {
  const _WeeklyStatsChart({required this.data});

  final List<WeeklyStat> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxWorkouts = data
        .map((d) => d.workoutsCompleted)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly Statistics', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxWorkouts + 2,
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Week',
                    style: theme.textTheme.bodySmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          data[index].weekLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Workouts',
                    style: theme.textTheme.bodySmall,
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0) return const SizedBox.shrink();
                      return Text(
                        value.toInt().toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: true),
              barGroups: data.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.workoutsCompleted.toDouble(),
                      color: theme.colorScheme.primary,
                      width: 20,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Displays a list of recently completed workouts.
class _RecentWorkouts extends StatelessWidget {
  const _RecentWorkouts({required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Workouts', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: Text('No completed workouts yet.')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _WorkoutSessionTile(session: session);
            },
          ),
      ],
    );
  }
}

class _WorkoutSessionTile extends StatelessWidget {
  const _WorkoutSessionTile({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      title: Text(
        session.workoutName,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        '${formatDate(session.completedAt)} • '
        '${formatDuration(session.totalDurationSeconds)} • '
        '${session.exercisesCompleted} exercises',
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.go('/progress/session/${session.id}');
      },
    );
  }
}
