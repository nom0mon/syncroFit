import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/edge_fade_gradient.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/progress_provider.dart';

/// Displays progress summary with stats, charts, and recent workout history.
///
/// Derives all statistics from WorkoutHistory records instead of a separate
/// progress table.
class ProgressSummaryScreen extends ConsumerWidget {
  const ProgressSummaryScreen({super.key});

  /// Forces a refresh by calling refreshCaches with forceRefresh: true,
  /// which invalidates cache metadata and forces a backend fetch regardless
  /// of cache age, then reloads the progress data.
  Future<void> _onRefresh(WidgetRef ref) async {
    final syncEngine = ref.read(syncEngineProvider);
    await syncEngine.refreshCaches(forceRefresh: true);
    ref.invalidate(progressProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: progressAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => RefreshIndicator(
          onRefresh: () => _onRefresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ErrorDisplay(
                message: error.toString(),
                onRetry: () => ref.invalidate(progressProvider),
              ),
            ],
          ),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () => _onRefresh(ref),
          child: _ProgressContent(state: state),
        ),
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryStats(state: state),
              const SizedBox(height: AppSpacing.lg),
              _WeeklyStatsChart(data: state.weeklyStats),
              const SizedBox(height: AppSpacing.lg),
              _RecentWorkouts(history: state.recentHistory),
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

/// Displays summary stat cards: total workouts and total duration.
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
              label: 'Total Duration',
              value: formatDuration(state.totalDurationSeconds),
              icon: Icons.timer,
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

/// Displays a list of recently completed workouts from WorkoutHistory.
class _RecentWorkouts extends StatelessWidget {
  const _RecentWorkouts({required this.history});

  final List<WorkoutHistory> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Workouts', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: Text('No completed workouts yet.')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = history[index];
              return _WorkoutHistoryTile(record: record);
            },
          ),
      ],
    );
  }
}

class _WorkoutHistoryTile extends StatelessWidget {
  const _WorkoutHistoryTile({required this.record});

  final WorkoutHistory record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      title: Text(
        record.workoutName,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        '${formatDate(record.completedAt)} • '
        '${formatDuration(record.totalDurationSeconds)} • '
        '${record.exercisesCompleted.length} exercises',
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
