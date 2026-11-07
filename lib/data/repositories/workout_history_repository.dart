import '../../shared/models/models.dart';

/// Abstract interface for workout history operations.
abstract class WorkoutHistoryRepository {
  /// Retrieves all workout history records for the authenticated user.
  Future<Result<List<WorkoutHistory>, AppError>> getAll(String userId);

  /// Retrieves workout history records within a date range.
  Future<Result<List<WorkoutHistory>, AppError>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  /// Records a completed workout session.
  ///
  /// When offline, the record is saved locally and queued for sync.
  Future<Result<WorkoutHistory, AppError>> save(WorkoutHistory record);

  /// Deletes a workout history record by its [id].
  ///
  /// When offline, the deletion is applied locally and queued for sync.
  Future<Result<void, AppError>> delete(String id);

  /// Updates an existing workout history record (overwrite flow).
  ///
  /// Sends a PATCH request with the updated exercise data and duration.
  /// When offline, the update is applied locally and queued for sync.
  Future<Result<WorkoutHistory, AppError>> update(WorkoutHistory record);
}
