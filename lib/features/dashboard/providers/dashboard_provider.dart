import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/caching/caching_providers.dart';
import '../../../data/repositories/workout_history_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../shared/models/models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../workout/providers/workout_history_refresh_provider.dart';

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
  Set<DateTime> get completedDates => history.map((h) {
        final local = h.effectiveCompletedAt;
        return DateTime(local.year, local.month, local.day);
      }).toSet();

  /// Returns history records completed on the given [date].
  List<WorkoutHistory> historyForDate(DateTime date) => history.where((h) {
        final local = h.effectiveCompletedAt;
        return local.year == date.year &&
            local.month == date.month &&
            local.day == date.day;
      }).toList();
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
    // Keep mounted dashboard tabs in sync with newly completed workouts.
    ref.watch(workoutHistoryRefreshProvider);
    final userId = ref.watch(authStateProvider).user?.id;

    // Fetch data concurrently for efficiency
    final results = await Future.wait([
      _workoutRepo.getTodaysWorkout(),
      _workoutRepo.getAll(),
      _historyRepo.getAll(userId ?? ''),
    ]);

    final workoutResult = results[0] as Result<Workout?, AppError>;
    final workoutsResult = results[1] as Result<List<Workout>, AppError>;
    final historyResult = results[2] as Result<List<WorkoutHistory>, AppError>;

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
    final scheduledWorkouts = switch (workoutsResult) {
      Success(value: final workouts) => workouts,
      Failure() => <Workout>[],
    };

    final weeklyProgress = calculateWeeklyProgress(
      history: history,
      workouts: scheduledWorkouts,
      now: DateTime.now(),
    );

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
        .map((h) {
          final local = h.effectiveCompletedAt;
          return DateTime(local.year, local.month, local.day);
        })
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
}

class WeeklyProgress {
  final int completed;
  final int planned;

  const WeeklyProgress({required this.completed, required this.planned});
}

/// Calculates progress only for days represented by the accepted schedule.
/// Multiple completed sessions on one day count as one completed workout day.
WeeklyProgress calculateWeeklyProgress({
  required List<WorkoutHistory> history,
  required List<Workout> workouts,
  required DateTime now,
}) {
  final scheduledWeekdays = workouts
      .where((workout) => workout.isAccepted)
      .map((workout) => _parseScheduledWeekday(workout.dayOfWeek))
      .whereType<int>()
      .toSet();
  final planned = scheduledWeekdays.length;
  if (planned == 0) return const WeeklyProgress(completed: 0, planned: 0);

  final weekStartValue = now.subtract(Duration(days: now.weekday - 1));
  final weekStart = DateTime(
    weekStartValue.year,
    weekStartValue.month,
    weekStartValue.day,
  );
  final nextWeek = weekStart.add(const Duration(days: 7));
  final completedDates = history
      .where((record) {
        final completedAt = record.effectiveCompletedAt;
        return !completedAt.isBefore(weekStart) &&
            completedAt.isBefore(nextWeek) &&
            scheduledWeekdays.contains(completedAt.weekday);
      })
      .map((record) => DateTime(
            record.effectiveCompletedAt.year,
            record.effectiveCompletedAt.month,
            record.effectiveCompletedAt.day,
          ))
      .toSet();

  return WeeklyProgress(
    completed: completedDates.length.clamp(0, planned),
    planned: planned,
  );
}

int? _parseScheduledWeekday(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final normalized = value.trim().toLowerCase();
  final numeric = int.tryParse(normalized);
  if (numeric != null && numeric >= 1 && numeric <= 7) return numeric;
  const names = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  final index = names.indexOf(normalized);
  return index < 0 ? null : index + 1;
}
