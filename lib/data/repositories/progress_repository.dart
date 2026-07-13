import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for progress tracking operations.
abstract class ProgressRepository {
  /// Retrieves all progress records.
  Future<Result<List<ProgressRecord>, AppError>> getRecords();

  /// Retrieves weekly workout statistics.
  Future<Result<Map<String, int>, AppError>> getWeeklyStats();

  /// Retrieves the overall progress summary.
  Future<Result<ProgressSummary, AppError>> getSummary();
}

/// A summary of the user's overall progress.
class ProgressSummary {
  final int totalWorkouts;
  final int currentStreak;
  final int longestStreak;
  final double currentWeightKg;

  const ProgressSummary({
    required this.totalWorkouts,
    required this.currentStreak,
    required this.longestStreak,
    required this.currentWeightKg,
  });
}
