import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/edge_fade_gradient.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/progress_provider.dart';
import '../utils/bmi_utils.dart';
import '../widgets/progress_log_timeline.dart';

/// Displays progress summary with stats, charts, and recent workout history.
///
/// [photosSection] is the responsive integration point for the progress-photo
/// timeline/grid. It remains absent until that feature supplies its content.
class ProgressSummaryScreen extends ConsumerWidget {
  const ProgressSummaryScreen({
    super.key,
    this.photosSection,
  });

  final Widget? photosSection;

  Future<void> _onRefresh(WidgetRef ref) async {
    final syncEngine = ref.read(syncEngineProvider);
    await syncEngine.refreshCaches(forceRefresh: true);
    ref.invalidate(profileProvider);
    ref.invalidate(progressProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressProvider);
    final bmiAsync = ref.watch(bmiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'Log Progress',
            onPressed: () => context.push('/progress/log'),
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: progressAsync.when(
          loading: () => const ResponsiveConstrainedPage(
            child: Center(child: LoadingIndicator()),
          ),
          error: (error, _) => RefreshIndicator(
            onRefresh: () => _onRefresh(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ResponsiveConstrainedPage(
                  child: ErrorDisplay(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(progressProvider),
                  ),
                ),
              ],
            ),
          ),
          data: (state) => RefreshIndicator(
            onRefresh: () => _onRefresh(ref),
            child: _ProgressContent(
              state: state,
              bmiAsync: bmiAsync,
              photosSection: photosSection ?? const ProgressLogTimeline(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.state,
    required this.bmiAsync,
    this.photosSection,
  });

  final ProgressState state;
  final AsyncValue<BmiResult?> bmiAsync;
  final Widget? photosSection;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: 100,
          ),
          child: ResponsiveConstrainedPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ThisWeekProgress(state: state),
                const SizedBox(height: AppSpacing.lg),
                _BmiSection(bmiAsync: bmiAsync),
                const SizedBox(height: AppSpacing.lg),
                _SummaryStats(state: state),
                if (photosSection != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  KeyedSubtree(
                    key: const Key('progress-photos-integration-point'),
                    child: photosSection!,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _WeeklyStatsChart(data: state.weeklyStats),
                const SizedBox(height: AppSpacing.lg),
                _RecentWorkouts(history: state.recentHistory),
              ],
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: EdgeFadeGradient(isTop: true),
        ),
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

class _BmiSection extends StatelessWidget {
  const _BmiSection({required this.bmiAsync});

  final AsyncValue<BmiResult?> bmiAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BMI', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        bmiAsync.when(
          loading: () => const ResponsiveCard(
            key: Key('bmi-loading'),
            margin: EdgeInsets.zero,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => ResponsiveCard(
            key: const Key('bmi-error'),
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BMI is temporarily unavailable.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => context.push('/settings/profile'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('View Profile'),
                ),
              ],
            ),
          ),
          data: (bmi) => bmi == null
              ? ResponsiveCard(
                  key: const Key('bmi-profile-required'),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set up your height and weight to calculate your BMI.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: () => context.push('/profile-setup'),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Set Up Profile'),
                      ),
                    ],
                  ),
                )
              : ResponsiveCard(
                  key: const Key('bmi-result'),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            bmi.displayValue,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Chip(label: Text(bmi.category.label)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Calculated from your profile height and weight. '
                        'BMI categories are informational and are not medical advice.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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

class _ThisWeekProgress extends StatelessWidget {
  const _ThisWeekProgress({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = state.plannedThisWeek;
    final completed = state.completedThisWeek;
    final remaining = (planned - completed).clamp(0, planned);
    final ratio = planned > 0 ? (completed / planned).clamp(0.0, 1.0) : 0.0;

    if (planned == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Week', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        ResponsiveCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    '$completed of $planned completed',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    remaining == 0 ? 'All done' : '$remaining remaining',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Summary', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AdaptiveGridList(
          minItemWidth: 180 * textScale.clamp(1, 2),
          maxColumns: 2,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
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

    return ResponsiveCard(
      margin: EdgeInsets.zero,
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
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WeeklyStatsChart extends StatelessWidget {
  const _WeeklyStatsChart({required this.data});

  final List<WeeklyStat> data;

  String _labelFor(String label, ChartLabelDensity density) {
    if (density == ChartLabelDensity.full) return label;
    final weekMarker = label.lastIndexOf('W');
    return weekMarker >= 0 ? label.substring(weekMarker) : label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) return const SizedBox.shrink();

    final maxWorkouts = data
        .map((entry) => entry.workoutsCompleted)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final semanticSummary = data
        .map((entry) =>
            '${entry.weekLabel}: ${entry.workoutsCompleted} workouts')
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly Statistics', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final density = ResponsiveStandards.chartLabelDensityFor(width);
            final stride = ResponsiveStandards.chartLabelStrideFor(
              width,
              data.length,
            );
            final showAxisNames = density != ChartLabelDensity.sparse;

            return Semantics(
              label: 'Weekly workout chart. $semanticSummary',
              image: true,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 220,
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
                          axisNameWidget: showAxisNames
                              ? Text('Week', style: theme.textTheme.bodySmall)
                              : null,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: showAxisNames ? 40 : 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 ||
                                  index >= data.length ||
                                  index % stride != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _labelFor(data[index].weekLabel, density),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          axisNameWidget: showAxisNames
                              ? Text(
                                  'Workouts',
                                  style: theme.textTheme.bodySmall,
                                )
                              : null,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: showAxisNames ? 38 : 28,
                            getTitlesWidget: (value, meta) {
                              if (value % 1 != 0) {
                                return const SizedBox.shrink();
                              }
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
                              width:
                                  density == ChartLabelDensity.sparse ? 12 : 20,
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
              ),
            );
          },
        ),
      ],
    );
  }
}

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
            itemBuilder: (context, index) =>
                _WorkoutHistoryTile(record: history[index]),
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatDate(record.completedAt)} • '
        '${formatDuration(record.totalDurationSeconds)} • '
        '${record.exercisesCompleted.length} exercises',
        style: theme.textTheme.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
