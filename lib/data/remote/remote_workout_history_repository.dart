import '../../core/models/workout_history.dart';
import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';
import '../repositories/workout_history_repository.dart';

/// Remote implementation of [WorkoutHistoryRepository] that communicates
/// with the Laravel backend via [ApiClient].
///
/// Backend endpoints used:
/// - GET  /api/workout-history → list workout history for authenticated user
/// - POST /api/workout-history → record a completed workout
class RemoteWorkoutHistoryRepository implements WorkoutHistoryRepository {
  final ApiClient _apiClient;

  RemoteWorkoutHistoryRepository(this._apiClient);

  @override
  Future<Result<List<WorkoutHistory>, AppError>> getAll(String userId) async {
    return _apiClient.get<List<WorkoutHistory>>(
      '/api/workout-history',
      fromJson: (json) => _parseWorkoutHistoryList(json),
    );
  }

  @override
  Future<Result<List<WorkoutHistory>, AppError>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return _apiClient.get<List<WorkoutHistory>>(
      '/api/workout-history',
      queryParameters: {
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
      },
      fromJson: (json) => _parseWorkoutHistoryList(json),
    );
  }

  @override
  Future<Result<WorkoutHistory, AppError>> save(WorkoutHistory record) async {
    return _apiClient.post<WorkoutHistory>(
      '/api/workout-history',
      body: {
        'workout_name': record.workoutName,
        'completed_at': record.completedAt.toIso8601String(),
        'total_duration_seconds': record.totalDurationSeconds,
        'exercises_completed': record.exercisesCompleted,
      },
      fromJson: (json) =>
          WorkoutHistory.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Parses a list of workout history records from the API response.
  List<WorkoutHistory> _parseWorkoutHistoryList(dynamic json) {
    if (json is List) {
      return json
          .map((item) =>
              WorkoutHistory.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
