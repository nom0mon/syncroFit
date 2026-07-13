import 'package:synchrofit/data/repositories/progress_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [ProgressRepository] using in-memory data with artificial delays.
class MockProgressRepository implements ProgressRepository {
  final List<ProgressRecord> _records = List.of(MockData.progressRecords);

  @override
  Future<Result<List<ProgressRecord>, AppError>> getRecords() async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Return sorted by date descending (newest first)
    final sorted = List<ProgressRecord>.from(_records)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Success(sorted);
  }

  @override
  Future<Result<Map<String, int>, AppError>> getWeeklyStats() async {
    await Future.delayed(const Duration(milliseconds: 250));

    // Generate weekly stats from the progress records
    final stats = <String, int>{};
    for (final record in _records) {
      final weekLabel = _getWeekLabel(record.date);
      stats[weekLabel] = (stats[weekLabel] ?? 0) + record.workoutsCompleted;
    }

    return Success(stats);
  }

  @override
  Future<Result<ProgressSummary, AppError>> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 300));

    final totalWorkouts = _records.fold<int>(
      0,
      (sum, r) => sum + r.workoutsCompleted,
    );

    final latestWeight =
        _records.isNotEmpty ? _records.last.weightKg : 0.0;

    return Success(
      ProgressSummary(
        totalWorkouts: totalWorkouts,
        currentStreak: 7,
        longestStreak: 14,
        currentWeightKg: latestWeight,
      ),
    );
  }

  String _getWeekLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff < 7) return 'This Week';
    if (diff < 14) return 'Last Week';
    if (diff < 21) return '3 Weeks Ago';
    return '4+ Weeks Ago';
  }
}
