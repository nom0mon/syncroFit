import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/repositories/exercise_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Remote implementation of [ExerciseRepository] that delegates to the
/// Laravel backend via [ApiClient].
///
/// Backend endpoints:
/// - GET /api/exercises?page=N&page_size=20&muscle_group=X&difficulty=Y&equipment=Z
/// - GET /api/exercises/{id}
///
/// Response envelope: {"success": true, "data": {"exercises": [...], "pagination": {...}}}
class RemoteExerciseRepository implements ExerciseRepository {
  final ApiClient _apiClient;

  RemoteExerciseRepository(this._apiClient);

  @override
  Future<Result<List<Exercise>, AppError>> getAll() async {
    return _fetchExercises();
  }

  @override
  Future<Result<Exercise, AppError>> getById(String id) async {
    final result = await _apiClient.get<Exercise>(
      '/api/exercises/$id',
      fromJson: (json) => Exercise.fromJson(json as Map<String, dynamic>),
    );
    return result;
  }

  @override
  Future<Result<List<Exercise>, AppError>> search(String query) async {
    // Backend doesn't have a dedicated search endpoint — filter client-side
    final all = await _fetchExercises();
    switch (all) {
      case Success(value: final exercises):
        final filtered = exercises
            .where(
                (e) => e.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return Success(filtered);
      case Failure(error: final error):
        return Failure(error);
    }
  }

  @override
  Future<Result<List<Exercise>, AppError>> filterByMuscleGroup(
    List<String> groups,
  ) async {
    // Use the first group for the API call (API accepts one at a time)
    return _fetchExercises(muscleGroup: groups.isNotEmpty ? groups.first : null);
  }

  @override
  Future<Result<List<Exercise>, AppError>> filterByDifficulty(
    String difficulty,
  ) async {
    return _fetchExercises(difficulty: difficulty);
  }

  /// Fetches exercises from the backend with optional filters.
  ///
  /// Uses a large page_size to retrieve all matching exercises in one request,
  /// which supports the infinite scroll pattern by providing a full dataset
  /// that the UI can page through locally.
  Future<Result<List<Exercise>, AppError>> _fetchExercises({
    String? muscleGroup,
    String? difficulty,
  }) async {
    final queryParams = <String, dynamic>{'page_size': 100};
    if (muscleGroup != null) queryParams['muscle_group'] = muscleGroup;
    if (difficulty != null) queryParams['difficulty'] = difficulty;

    final result = await _apiClient.get<List<Exercise>>(
      '/api/exercises',
      queryParameters: queryParams,
      fromJson: (json) {
        final data = json as Map<String, dynamic>;
        final exercises = data['exercises'] as List<dynamic>;
        return exercises
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
    return result;
  }
}
