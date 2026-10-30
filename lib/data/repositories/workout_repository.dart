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

/// Result of a workout generation call.
///
/// Carries both the generated workouts and the number of exercise slots the
/// engine could not fill (see `meta.unresolved_slots` in the backend
/// response). Zero means every slot was filled.
class GenerationResult {
  const GenerationResult({
    required this.workouts,
    this.unresolvedSlots = 0,
  });

  final List<Workout> workouts;
  final int unresolvedSlots;
}

/// Additional capability for generating and persistently caching a plan.
abstract class WorkoutGenerationRepository {
  Future<Result<GenerationResult, AppError>> generateRecommendation({
    List<int> includedExercises = const [],
    List<int> excludedExercises = const [],
    FitnessLevel? fitnessLevel,
    FitnessGoal? fitnessGoal,
    WorkoutPreference? workoutPreference,
    bool saveOptionsToProfile = false,
  });
}

abstract class WorkoutPlanAcceptanceRepository {
  Future<Result<List<Workout>, AppError>> acceptPlan(String planId);
}
