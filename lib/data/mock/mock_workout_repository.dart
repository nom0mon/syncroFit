import 'package:synchrofit/data/repositories/workout_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [WorkoutRepository] using in-memory data with artificial delays.
class MockWorkoutRepository implements WorkoutRepository {
  final List<Workout> _workouts = List.of(MockData.workouts);

  @override
  Future<Result<List<Workout>, AppError>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Success(List.unmodifiable(_workouts));
  }

  @override
  Future<Result<Workout, AppError>> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _workouts.indexWhere((w) => w.id == id);
    if (index == -1) {
      return Failure(NotFoundError(entityType: 'Workout', id: id));
    }
    return Success(_workouts[index]);
  }

  @override
  Future<Result<Workout?, AppError>> getTodaysWorkout() async {
    await Future.delayed(const Duration(milliseconds: 250));

    // Always return the first workout as today's scheduled workout
    if (_workouts.isNotEmpty) {
      return Success(_workouts.first);
    }
    return const Success(null);
  }
}
