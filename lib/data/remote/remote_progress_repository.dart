import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/repositories/progress_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Remote implementation of [ProgressRepository] that delegates to the
/// Laravel backend via [ApiClient].
///
/// Backend endpoints:
/// - GET /api/progress/summary  → progress summary (total workouts, streaks, weight)
/// - GET /api/progress/history  → all progress records ordered by date
/// - GET /api/progress/weekly-stats → workouts completed per day for current week
class RemoteProgressRepository implements ProgressRepository {
  final ApiClient _apiClient;

  RemoteProgressRepository(this._apiClient);

  @override
  Future<Result<List<ProgressRecord>, AppError>> getRecords() async {
    final result = await _apiClient.get<List<ProgressRecord>>(
      '/api/progress/history',
      fromJson: (json) {
        final data = json as Map<String, dynamic>;
        final records = data['records'] as List<dynamic>;
        return records
            .map((r) => ProgressRecord.fromJson(r as Map<String, dynamic>))
            .toList();
      },
    );
    return result;
  }

  @override
  Future<Result<Map<String, int>, AppError>> getWeeklyStats() async {
    final result = await _apiClient.get<Map<String, int>>(
      '/api/progress/weekly-stats',
      fromJson: (json) {
        final data = json as Map<String, dynamic>;
        final stats = data['weekly_stats'] as List<dynamic>;
        final map = <String, int>{};
        for (final item in stats) {
          final entry = item as Map<String, dynamic>;
          map[entry['day'] as String] = entry['workouts_completed'] as int;
        }
        return map;
      },
    );
    return result;
  }

  @override
  Future<Result<ProgressSummary, AppError>> getSummary() async {
    final result = await _apiClient.get<ProgressSummary>(
      '/api/progress/summary',
      fromJson: (json) {
        final data = json as Map<String, dynamic>;
        return ProgressSummary(
          totalWorkouts: data['total_workouts'] as int,
          currentStreak: data['current_streak'] as int,
          longestStreak: data['longest_streak'] as int,
          currentWeightKg: (data['latest_weight'] as num?)?.toDouble() ?? 0.0,
        );
      },
    );
    return result;
  }
}
