import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/repositories/workout_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Remote implementation of [WorkoutRepository] that communicates with
/// the Laravel backend via [ApiClient].
///
/// Backend endpoints used:
/// - GET  /api/workouts → list workouts
/// - POST /api/workouts → create a workout
/// - POST /api/workouts/generate → generate new recommendation
/// - GET  /api/workouts/generated → list generated workouts
class RemoteWorkoutRepository
    implements
        WorkoutRepository,
        WorkoutCustomizationRepository,
        WorkoutGenerationRepository,
        WorkoutPlanAcceptanceRepository {
  final ApiClient _apiClient;

  RemoteWorkoutRepository(this._apiClient);

  @override
  Future<Result<List<Workout>, AppError>> getAll() async {
    final result = await _apiClient.get<List<Workout>>(
      '/api/workouts',
      fromJson: (json) => _parseWorkoutsList(json),
    );
    return result;
  }

  @override
  Future<Result<Workout, AppError>> getById(String id) async {
    final result = await _apiClient.get<List<Workout>>(
      '/api/workouts',
      fromJson: (json) => _parseWorkoutsList(json),
    );

    switch (result) {
      case Success(value: final workouts):
        final match = workouts.where((w) => w.id == id);
        if (match.isEmpty) {
          return Failure(NotFoundError(entityType: 'Workout', id: id));
        }
        return Success(match.first);
      case Failure(error: final error):
        return Failure(error);
    }
  }

  @override
  Future<Result<Workout?, AppError>> getTodaysWorkout() async {
    final result = await _apiClient.get<Workout?>(
      '/api/workouts',
      fromJson: (json) {
        final workouts = _parseWorkoutsList(json);
        final today = _todayDayOfWeek();
        final match = workouts.where((w) => w.dayOfWeek == today.toString());
        return match.isEmpty ? null : match.first;
      },
    );
    return result;
  }

  @override
  Future<Result<Workout, AppError>> customizeExercises(
    String workoutId,
    List<int> exerciseIds,
  ) {
    return _apiClient.put<Workout>(
      '/api/workouts/$workoutId/exercises',
      body: {'exercise_ids': exerciseIds},
      fromJson: (json) => Workout.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Generates new workouts via the recommendation engine.
  ///
  /// POST /api/workouts/generate
  ///
  /// Optionally accepts [includedExercises] and [excludedExercises] as lists
  /// of exercise IDs. These are only sent when non-empty. The backend accepts
  /// a JSON body `{ "included_exercises": [...], "excluded_exercises": [...] }`.
  @override
  Future<Result<List<Workout>, AppError>> generateRecommendation({
    List<int> includedExercises = const [],
    List<int> excludedExercises = const [],
  }) async {
    return _apiClient.post<List<Workout>>(
      '/api/workouts/generate',
      body: {
        if (includedExercises.isNotEmpty)
          'included_exercises': includedExercises,
        if (excludedExercises.isNotEmpty)
          'excluded_exercises': excludedExercises,
      },
      fromJson: (json) => _parseWorkoutsList(json),
    );
  }

  /// Retrieves only generated workouts.
  ///
  /// GET /api/workouts/generated
  Future<Result<List<Workout>, AppError>> getGenerated() async {
    return _apiClient.get<List<Workout>>(
      '/api/workouts/generated',
      fromJson: (json) => _parseWorkoutsList(json),
    );
  }

  @override
  Future<Result<List<Workout>, AppError>> acceptPlan(String planId) {
    return _apiClient.post<List<Workout>>(
      '/api/workouts/plans/$planId/accept',
      fromJson: (json) => _parseWorkoutsList(json),
    );
  }

  // ─── Private Helpers ──────────────────────────────────────────────────

  /// Parses workouts from a list response.
  List<Workout> _parseWorkoutsList(dynamic json) {
    if (json is Map<String, dynamic>) {
      final workoutsJson = json['workouts'] as List<dynamic>?;
      if (workoutsJson != null) {
        return workoutsJson
            .map((w) => Workout.fromJson(w as Map<String, dynamic>))
            .toList();
      }
      // Single workout response wrapped in an object
      if (json.containsKey('id')) {
        return [Workout.fromJson(json)];
      }
    }
    if (json is List<dynamic>) {
      return json
          .map((w) => Workout.fromJson(w as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Returns today's day of week as an integer (1 = Monday, 7 = Sunday),
  /// matching the backend's convention.
  int _todayDayOfWeek() {
    return DateTime.now().weekday; // Dart: 1 = Monday, 7 = Sunday
  }
}
