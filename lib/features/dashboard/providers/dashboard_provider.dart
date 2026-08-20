import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/caching/caching_providers.dart';
import '../../../data/repositories/workout_history_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [WorkoutRepository] instance used by the dashboard.
///
/// Uses [CachingWorkoutRepository] which wraps the remote repository with
/// local SQLite caching and offline support. The provider can be overridden
/// with a mock in tests via ProviderScope overrides.
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return ref.watch(cachingWorkoutRepositoryProvider);
});

/// Provides the [WorkoutHistoryRepository] instance used by the dashboard.
///
/// Uses [CachingWorkoutHistoryRepository] which wraps the remote repository
/// with local SQLite caching and offline support.
final dashboardHistoryRepositoryProvider =
    Provider<WorkoutHistoryRepository>((ref) {
  return ref.watch(cachingWorkoutHistoryRepositoryProvider);
});

/// The state exposed by the dashboard provider, containing all data needed
/// to render the dashboard screen.
class DashboardState {
  /// Today's scheduled workout, or null if none is planned.
  final Workout? todaysWorkout;

  /// Number of workout days completed this week.
  final int completedDays;

  /// Number of planned workout days this week.
  final int plannedDays;

  /// Goal progress as a percentage (0–100).
  final int goalPercentage;

  /// Consecutive workout day streak.
  final int streak;

  /// All completed workout history records (used by calendar and chart widgets).
  final List<WorkoutHistory> history;

  const DashboardState({
    this.todaysWorkout,
    this.completedDays = 0,
    this.plannedDays = 0,
    this.goalPercentage = 0,
    this.streak = 0,
    this.history = const [],
  });

  /// Derives a set of dates (year/month/day only) with completed workouts.
  Set<DateTime> get completedDates => history
      .map((h) =>
          DateTime(h.completedAt.year, h.completedAt.month, h.completedAt.day))
      .toSet();

  /// Returns history records completed on the given [date].
  List<WorkoutHistory> historyForDate(DateTime date) => history
      .where((h) =>
          h.completedAt.year == date.year &&
          h.completedAt.month == date.month &&
          h.completedAt.day == date.day)
      .toList();
}

/// Provides the dashboard data as an async value, managed by [DashboardNotifier].
///
/// Fetches today's workout, workout history, and computes weekly progress
/// and goal percentage from the repositories.
final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});

/// An [AsyncNotifier] that loads all dashboard data from the workout and
/// workout history repositories.
class DashboardNotifier extends AsyncNotifier<DashboardState> {
  WorkoutRepository get _workoutRepo => ref.read(workoutRepositoryProvider);
  WorkoutHistoryRepository get _historyRepo =>
      ref.read(dashboardHistoryRepositoryProvider);

  @override
  Future<DashboardState> build() async {
    // Fetch data concurrently for efficiency
    final results = await Future.wait([
      _workoutRepo.getTodaysWorkout(),
      _historyRepo.getAll(''),
    ]);

    final workoutResult = results[0] as Result<Workout?, AppError>;
    final historyResult =
        results[1] as Result<List<WorkoutHistory>, AppError>;

    // Extract today's workout
    final todaysWorkout = switch (workoutResult) {
      Success(value: final workout) => workout,
      Failure() => null,
    };

    // Extract workout history
    final history = switch (historyResult) {
      Success(value: final h) => h,
      Failure() => <WorkoutHistory>[],
    };

    final weeklyProgress = _calculateWeeklyProgress(history);

    // Calculate goal percentage based on workouts completed.
    final goalPercentage = _calculateGoalPercentage(history.length);

    // Calculate streak from history
    final streak = _calculateStreak(history);

    return DashboardState(
      todaysWorkout: todaysWorkout,
      completedDays: weeklyProgress.completed,
      plannedDays: weeklyProgress.planned,
      goalPercentage: goalPercentage,
      streak: streak,
      history: history,
    );
  }

  /// Calculates how many days were completed this week and how many were planned.
  _WeeklyProgress _calculateWeeklyProgress(List<WorkoutHistory> history) {
    final now = DateTime.now();
    // Find the start of the current week (Monday)
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    // Count records completed this week
    final completedThisWeek = history.where((record) {
      return record.completedAt.isAfter(weekStartDate) ||
          _isSameDay(record.completedAt, weekStartDate);
    }).length;

    // Planned days based on user profile workout availability (default 3 days/week)
    const plannedDaysPerWeek = 3;

    return _WeeklyProgress(
      completed: completedThisWeek,
      planned: plannedDaysPerWeek,
    );
  }

  /// Calculates goal progress as a percentage (0–100).
  /// Uses total workouts toward a monthly goal target.
  int _calculateGoalPercentage(int totalWorkouts) {
    // Target: 20 workouts per month as a reasonable fitness goal
    const monthlyTarget = 20;
    final percentage = ((totalWorkouts / monthlyTarget) * 100).round();
    return percentage.clamp(0, 100);
  }

  /// Calculates the current consecutive workout day streak from history.
  int _calculateStreak(List<WorkoutHistory> history) {
    if (history.isEmpty) return 0;

    // Get unique dates sorted descending
    final dates = history
        .map((h) =>
            DateTime(h.completedAt.year, h.completedAt.month, h.completedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) return 0;

    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i - 1].difference(dates[i]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Internal helper class for weekly progress calculation.
class _WeeklyProgress {
  final int completed;
  final int planned;

  const _WeeklyProgress({required this.completed, required this.planned});
}
