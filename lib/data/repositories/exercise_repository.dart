import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for exercise library operations.
abstract class ExerciseRepository {
  /// Retrieves all exercises.
  Future<Result<List<Exercise>, AppError>> getAll();

  /// Retrieves a single exercise by its ID.
  Future<Result<Exercise, AppError>> getById(String id);

  /// Searches exercises by a query string (case-insensitive substring match).
  Future<Result<List<Exercise>, AppError>> search(String query);

  /// Filters exercises by one or more muscle groups.
  Future<Result<List<Exercise>, AppError>> filterByMuscleGroup(
    List<String> groups,
  );

  /// Filters exercises by difficulty level.
  Future<Result<List<Exercise>, AppError>> filterByDifficulty(
      String difficulty);
}
