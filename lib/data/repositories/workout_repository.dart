import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for workout operations.
abstract class WorkoutRepository {
  /// Retrieves all available workouts.
  Future<Result<List<Workout>, AppError>> getAll();

  /// Retrieves a single workout by its ID.
  Future<Result<Workout, AppError>> getById(String id);

  /// Retrieves today's scheduled workout.
  Future<Result<Workout?, AppError>> getTodaysWorkout();

  /// Retrieves the history of completed workout sessions.
  Future<Result<List<WorkoutSession>, AppError>> getSessionHistory();

  /// Saves a completed workout session.
  Future<Result<WorkoutSession, AppError>> saveSession(WorkoutSession session);
}
