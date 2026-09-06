import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for workout operations.
abstract class WorkoutRepository {
  /// Retrieves all available workouts.
  Future<Result<List<Workout>, AppError>> getAll();

  /// Retrieves a single workout by its ID.
  Future<Result<Workout, AppError>> getById(String id);

  /// Retrieves today's scheduled workout.
  Future<Result<Workout?, AppError>> getTodaysWorkout();
}

/// Additional capability for changing generated workout exercise membership.
abstract class WorkoutCustomizationRepository {
  Future<Result<Workout, AppError>> customizeExercises(
    String workoutId,
    List<int> exerciseIds,
  );
}

/// Additional capability for generating and persistently caching a plan.
abstract class WorkoutGenerationRepository {
  Future<Result<List<Workout>, AppError>> generateRecommendation({
    List<int> includedExercises = const [],
    List<int> excludedExercises = const [],
  });
}

abstract class WorkoutPlanAcceptanceRepository {
  Future<Result<List<Workout>, AppError>> acceptPlan(String planId);
}
