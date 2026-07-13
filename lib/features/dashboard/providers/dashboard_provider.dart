import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_progress_repository.dart';
import '../../../data/mock/mock_workout_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [WorkoutRepository] instance used by the dashboard.
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return MockWorkoutRepository();
});

/// Provides the [ProgressRepository] instance used by the dashboard.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return MockProgressRepository();
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

  const DashboardState({
    this.todaysWorkout,
    this.completedDays = 0,
    this.plannedDays = 0,
    this.goalPercentage = 0,
    this.streak = 0,
  });
}

/// Provides the dashboard data as an async value, managed by [DashboardNotifier].
///
/// Fetches today's workout, weekly progress, goal percentage, and workout streak
/// from the mock repositories.
final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});

/// An [AsyncNotifier] that loads all dashboard data from the workout and
/// progress repositories.
class DashboardNotifier extends AsyncNotifier<DashboardState> {
  WorkoutRepository get _workoutRepo => ref.read(workoutRepositoryProvider);
  ProgressRepository get _progressRepo => ref.read(progressRepositoryProvider);

  @override
  Future<DashboardState> build() async {
    // Fetch data concurrently for efficiency
    final results = await Future.wait([
      _workoutRepo.getTodaysWorkout(),
      _progressRepo.getSummary(),
      _workoutRepo.getSessionHistory(),
    ]);

    final workoutResult = results[0] as Result<Workout?, AppError>;
    final summaryResult = results[1] as Result<ProgressSummary, AppError>;
    final sessionsResult = results[2] as Result<List<WorkoutSession>, AppError>;

    // Extract today's workout
    final todaysWorkout = switch (workoutResult) {
      Success(value: final workout) => workout,
      Failure() => null,
    };

    // Extract progress summary for streak and total workouts
    final summary = switch (summaryResult) {
      Success(value: final s) => s,
      Failure() => const ProgressSummary(
          totalWorkouts: 0,
          currentStreak: 0,
          longestStreak: 0,
          currentWeightKg: 0,
        ),
    };

    // Calculate weekly progress from session history
    final sessions = switch (sessionsResult) {
      Success(value: final s) => s,
      Failure() => <WorkoutSession>[],
    };

    final weeklyProgress = _calculateWeeklyProgress(sessions);

    // Calculate goal percentage based on workouts completed vs a target.
    // Using planned days per week as the target; scale across progress records.
    final goalPercentage = _calculateGoalPercentage(summary);

    return DashboardState(
      todaysWorkout: todaysWorkout,
      completedDays: weeklyProgress.completed,
      plannedDays: weeklyProgress.planned,
      goalPercentage: goalPercentage,
      streak: summary.currentStreak,
    );
  }

  /// Calculates how many days were completed this week and how many were planned.
  _WeeklyProgress _calculateWeeklyProgress(List<WorkoutSession> sessions) {
    final now = DateTime.now();
    // Find the start of the current week (Monday)
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    // Count sessions completed this week
    final completedThisWeek = sessions.where((session) {
      return session.completedAt.isAfter(weekStartDate) ||
          _isSameDay(session.completedAt, weekStartDate);
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
  int _calculateGoalPercentage(ProgressSummary summary) {
    // Target: 20 workouts per month as a reasonable fitness goal
    const monthlyTarget = 20;
    final percentage = ((summary.totalWorkouts / monthlyTarget) * 100).round();
    return percentage.clamp(0, 100);
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
