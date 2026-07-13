import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_progress_repository.dart';
import '../../../data/mock/mock_workout_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [ProgressRepository] instance used by the progress module.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return MockProgressRepository();
});

/// Provides the [WorkoutRepository] instance used by the progress module
/// (for fetching completed session history).
final progressWorkoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return MockWorkoutRepository();
});

/// A single weight data point for charting.
class WeightDataPoint {
  final DateTime date;
  final double weightKg;

  const WeightDataPoint({required this.date, required this.weightKg});
}

/// A single BMI data point for charting.
class BmiDataPoint {
  final DateTime date;
  final double bmi;

  const BmiDataPoint({required this.date, required this.bmi});
}

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

  /// Current consecutive workout day streak.
  final int currentStreak;

  /// Longest consecutive workout day streak.
  final int longestStreak;

  /// Current weight in kg.
  final double currentWeightKg;

  /// Weight history data points for charting (at least 5 points).
  final List<WeightDataPoint> weightHistory;

  /// BMI history data points for charting (at least 5 points).
  final List<BmiDataPoint> bmiHistory;

  /// Weekly statistics for the last 4 weeks.
  final List<WeeklyStat> weeklyStats;

  /// Recently completed workout sessions.
  final List<WorkoutSession> recentSessions;

  const ProgressState({
    this.totalWorkouts = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.currentWeightKg = 0.0,
    this.weightHistory = const [],
    this.bmiHistory = const [],
    this.weeklyStats = const [],
    this.recentSessions = const [],
  });
}

/// Provides the progress data as an async value, managed by [ProgressNotifier].
///
/// Fetches summary stats, weight history, BMI history, weekly stats, and
/// completed sessions from the mock repositories.
final progressProvider =
    AsyncNotifierProvider<ProgressNotifier, ProgressState>(() {
  return ProgressNotifier();
});

/// An [AsyncNotifier] that loads all progress tracking data from the
/// progress and workout repositories.
class ProgressNotifier extends AsyncNotifier<ProgressState> {
  ProgressRepository get _progressRepo =>
      ref.read(progressRepositoryProvider);
  WorkoutRepository get _workoutRepo =>
      ref.read(progressWorkoutRepositoryProvider);

  @override
  Future<ProgressState> build() async {
    // Fetch data concurrently for efficiency
    final results = await Future.wait([
      _progressRepo.getSummary(),
      _progressRepo.getRecords(),
      _progressRepo.getWeeklyStats(),
      _workoutRepo.getSessionHistory(),
    ]);

    final summaryResult = results[0] as Result<ProgressSummary, AppError>;
    final recordsResult =
        results[1] as Result<List<ProgressRecord>, AppError>;
    final weeklyStatsResult = results[2] as Result<Map<String, int>, AppError>;
    final sessionsResult =
        results[3] as Result<List<WorkoutSession>, AppError>;

    // Extract summary stats
    final summary = switch (summaryResult) {
      Success(value: final s) => s,
      Failure() => const ProgressSummary(
          totalWorkouts: 0,
          currentStreak: 0,
          longestStreak: 0,
          currentWeightKg: 0.0,
        ),
    };

    // Extract progress records for weight and BMI history
    final records = switch (recordsResult) {
      Success(value: final r) => r,
      Failure() => <ProgressRecord>[],
    };

    // Extract weekly stats
    final weeklyStatsMap = switch (weeklyStatsResult) {
      Success(value: final s) => s,
      Failure() => <String, int>{},
    };

    // Extract completed sessions
    final sessions = switch (sessionsResult) {
      Success(value: final s) => s,
      Failure() => <WorkoutSession>[],
    };

    // Build weight history from progress records (sorted by date ascending for charting)
    final sortedRecords = List<ProgressRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    final weightHistory = sortedRecords
        .map((r) => WeightDataPoint(date: r.date, weightKg: r.weightKg))
        .toList();

    // Build BMI history from progress records (sorted by date ascending for charting)
    final bmiHistory = sortedRecords
        .map((r) => BmiDataPoint(date: r.date, bmi: r.bmi))
        .toList();

    // Build weekly stats list from the map
    final weeklyStats = weeklyStatsMap.entries
        .map((e) => WeeklyStat(weekLabel: e.key, workoutsCompleted: e.value))
        .toList();

    return ProgressState(
      totalWorkouts: summary.totalWorkouts,
      currentStreak: summary.currentStreak,
      longestStreak: summary.longestStreak,
      currentWeightKg: summary.currentWeightKg,
      weightHistory: weightHistory,
      bmiHistory: bmiHistory,
      weeklyStats: weeklyStats,
      recentSessions: sessions,
    );
  }
}
