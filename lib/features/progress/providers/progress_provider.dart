import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/caching/caching_providers.dart';
import '../../../data/repositories/workout_history_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../shared/models/models.dart';
import '../../workout/providers/workout_provider.dart';

/// Provides the [WorkoutHistoryRepository] instance used by the progress module.
///
/// Uses the caching workout history repository which wraps the remote repository
/// with local SQLite caching and offline support.
final progressWorkoutHistoryRepositoryProvider =
    Provider<WorkoutHistoryRepository>((ref) {
  return ref.watch(cachingWorkoutHistoryRepositoryProvider);
});

/// Weekly statistic entry showing workouts completed in a given week.
class WeeklyStat {
  final String weekLabel;
  final int workoutsCompleted;

  const WeeklyStat({required this.weekLabel, required this.workoutsCompleted});
}

/// The complete state exposed by the progress provider.
class ProgressState {
  /// Total number of completed workouts.
  final int totalWorkouts;

  /// Total duration in seconds across all completed workouts.
  final int totalDurationSeconds;

  /// Weekly statistics for recent weeks.
  final List<WeeklyStat> weeklyStats;

  /// Recently completed workout history records.
  final List<WorkoutHistory> recentHistory;

  /// Number of workouts planned in the user's current weekly schedule.
  final int plannedThisWeek;

  /// Number of scheduled workouts completed so far this week.
  final int completedThisWeek;

  const ProgressState({
    this.totalWorkouts = 0,
    this.totalDurationSeconds = 0,
    this.weeklyStats = const [],
    this.recentHistory = const [],
    this.plannedThisWeek = 0,
    this.completedThisWeek = 0,
  });
}

/// Provides the progress data as an async value, managed by [ProgressNotifier].
///
/// Fetches workout history and derives summary statistics (total workouts,
/// total duration, weekly stats) from the WorkoutHistory records.
final progressProvider =
    AsyncNotifierProvider<ProgressNotifier, ProgressState>(() {
  return ProgressNotifier();
});

/// An [AsyncNotifier] that loads all progress tracking data from the
/// workout history repository and computes derived statistics.
class ProgressNotifier extends AsyncNotifier<ProgressState> {
  WorkoutHistoryRepository get _historyRepo =>
      ref.read(progressWorkoutHistoryRepositoryProvider);

  WorkoutRepository get _workoutRepo => ref.read(workoutRepositoryProvider);

  @override
  Future<ProgressState> build() async {
    // Use a dummy userId — in production this comes from the auth state.
    const userId = '';
    final historyResult = await _historyRepo.getAll(userId);

    final history = switch (historyResult) {
      Success(value: final records) => records,
      Failure() => <WorkoutHistory>[],
    };

    // Compute total workouts
    final totalWorkouts = history.length;

    // Compute total duration
    final totalDurationSeconds =
        history.fold<int>(0, (sum, record) => sum + record.totalDurationSeconds);

    // Compute weekly stats from history
    final weeklyStats = _computeWeeklyStats(history);

    // Sort by completedAt descending for recent history
    final sortedHistory = List<WorkoutHistory>.from(history)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    // Planned workouts this week = number of workouts in the user's plan.
    // Fetched via a one-shot repository call (not by watching the scheduler
    // StateNotifier, which emitted multiple states and caused this async
    // build to loop forever).
    final workoutsResult = await _workoutRepo.getAll();
    final plannedThisWeek = switch (workoutsResult) {
      Success(value: final workouts) => workouts.length,
      Failure() => 0,
    };

    // Completed this week = history records whose completedAt falls in the
    // current Monday–Sunday week.
    final (weekStart, weekEnd) = _currentWeekRange();
    final completedThisWeek = history.where((r) {
      return !r.completedAt.isBefore(weekStart) &&
          !r.completedAt.isAfter(weekEnd);
    }).length;

    return ProgressState(
      totalWorkouts: totalWorkouts,
      totalDurationSeconds: totalDurationSeconds,
      weeklyStats: weeklyStats,
      recentHistory: sortedHistory.take(10).toList(),
      plannedThisWeek: plannedThisWeek,
      completedThisWeek: completedThisWeek,
    );
  }

  /// Returns the Monday 00:00:00 → Sunday 23:59:59 range for the current week.
  (DateTime, DateTime) _currentWeekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sunday = DateTime(
      monday.year,
      monday.month,
      monday.day + 6,
      23,
      59,
      59,
    );
    return (monday, sunday);
  }

  /// Groups workout history records by ISO week and counts workouts per week.
  List<WeeklyStat> _computeWeeklyStats(List<WorkoutHistory> history) {
    final weekCounts = <String, int>{};

    for (final record in history) {
      final weekLabel = _getIsoWeekLabel(record.completedAt);
      weekCounts[weekLabel] = (weekCounts[weekLabel] ?? 0) + 1;
    }

    // Sort by week label descending and take last 4 weeks
    final entries = weekCounts.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return entries
        .take(4)
        .map((e) => WeeklyStat(weekLabel: e.key, workoutsCompleted: e.value))
        .toList();
  }

  /// Returns an ISO week label like "2024-W23" for the given date.
  String _getIsoWeekLabel(DateTime date) {
    // Calculate ISO week number
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final weekday = date.weekday; // 1=Mon, 7=Sun
    final weekNumber = ((dayOfYear - weekday + 10) / 7).floor();
    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }
}
