import 'package:synchrofit/data/repositories/exercise_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [ExerciseRepository] using in-memory data with artificial delays.
class MockExerciseRepository implements ExerciseRepository {
  final List<Exercise> _exercises = List.of(MockData.exercises);

  @override
  Future<Result<List<Exercise>, AppError>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Success(List.unmodifiable(_exercises));
  }

  @override
  Future<Result<Exercise, AppError>> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _exercises.indexWhere((e) => e.id == id);
    if (index == -1) {
      return Failure(NotFoundError(entityType: 'Exercise', id: id));
    }
    return Success(_exercises[index]);
  }

  @override
  Future<Result<List<Exercise>, AppError>> search(String query) async {
    await Future.delayed(const Duration(milliseconds: 250));

    final lowerQuery = query.toLowerCase();
    final results = _exercises
        .where((e) => e.name.toLowerCase().contains(lowerQuery))
        .toList();

    return Success(results);
  }

  @override
  Future<Result<List<Exercise>, AppError>> filterByMuscleGroup(
    List<String> groups,
  ) async {
    await Future.delayed(const Duration(milliseconds: 250));

    final lowerGroups = groups.map((g) => g.toLowerCase()).toList();
    final results = _exercises
        .where(
          (e) => lowerGroups.contains(e.muscleGroup.toLowerCase()),
        )
        .toList();

    return Success(results);
  }

  @override
  Future<Result<List<Exercise>, AppError>> filterByDifficulty(
    String difficulty,
  ) async {
    await Future.delayed(const Duration(milliseconds: 250));

    final difficultyLevel = DifficultyLevel.values.where(
      (d) => d.name.toLowerCase() == difficulty.toLowerCase(),
    );

    if (difficultyLevel.isEmpty) {
      return const Success([]);
    }

    final results =
        _exercises.where((e) => e.difficulty == difficultyLevel.first).toList();

    return Success(results);
  }
}
