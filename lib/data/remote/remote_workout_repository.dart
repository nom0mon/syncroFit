import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/repositories/workout_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Remote implementation of [WorkoutRepository] that communicates with
/// the Laravel backend via [ApiClient].
///
/// Backend endpoints used:
/// - GET  /api/recommendations/current → retrieve current plan (workouts list)
/// - POST /api/recommendations/generate → generate new recommendation
/// - POST /api/sessions → start a workout session
/// - PATCH /api/sessions/{id}/pause → pause an active session
/// - PATCH /api/sessions/{id}/resume → resume a paused session
/// - PATCH /api/sessions/{id}/skip-exercise → skip an exercise
/// - PATCH /api/sessions/{id}/complete → complete a session
///
/// This class extends the base [WorkoutRepository] interface with additional
/// session state machine methods for real-time workout tracking.
class RemoteWorkoutRepository implements WorkoutRepository {
  final ApiClient _apiClient;

  /// Locally retained session data for retry on completion failure.
  WorkoutSession? _pendingSession;

  RemoteWorkoutRepository(this._apiClient);

  /// Whether there is a pending session that failed to save.
  bool get hasPendingSession => _pendingSession != null;

  /// The pending session that failed to save, if any.
  WorkoutSession? get pendingSession => _pendingSession;

  @override
  Future<Result<List<Workout>, AppError>> getAll() async {
    final result = await _apiClient.get<List<Workout>>(
      '/api/recommendations/current',
      fromJson: (json) => _parseWorkoutsFromRecommendation(json),
    );
    return result;
  }

  @override
  Future<Result<Workout, AppError>> getById(String id) async {
    final result = await _apiClient.get<List<Workout>>(
      '/api/recommendations/current',
      fromJson: (json) => _parseWorkoutsFromRecommendation(json),
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
      '/api/recommendations/current',
      fromJson: (json) {
        final workouts = _parseWorkoutsWithDayOfWeek(json);
        final today = _todayDayOfWeek();
        final match = workouts.where((w) => w.dayOfWeek == today);
        return match.isEmpty ? null : match.first.workout;
      },
    );
    return result;
  }

  @override
  Future<Result<List<WorkoutSession>, AppError>> getSessionHistory() async {
    // The backend does not currently expose a session history endpoint.
    // Return an empty list as a stub; the progress endpoints cover history.
    return const Success([]);
  }

  @override
  Future<Result<WorkoutSession, AppError>> saveSession(
    WorkoutSession session,
  ) async {
    final result = await completeSession(session.id);

    switch (result) {
      case Success(value: final completedSession):
        _pendingSession = null;
        return Success(completedSession);
      case Failure(error: final error):
        // Retain session locally for retry on failure.
        _pendingSession = session;
        return Failure(error);
    }
  }

  /// Retries saving the pending session that previously failed.
  ///
  /// Returns null if there is no pending session.
  Future<Result<WorkoutSession, AppError>?> retryPendingSession() async {
    if (_pendingSession == null) return null;
    return saveSession(_pendingSession!);
  }

  // ─── Session State Machine Methods ───────────────────────────────────

  /// Starts a new workout session.
  ///
  /// POST /api/sessions with body: {workout_id: workoutId}
  /// Returns the created session with its ID and start timestamp.
  Future<Result<Map<String, dynamic>, AppError>> startSession(
    String workoutId,
  ) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/api/sessions',
      body: {'workout_id': workoutId},
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }

  /// Pauses an active workout session.
  ///
  /// PATCH /api/sessions/{id}/pause
  Future<Result<Map<String, dynamic>, AppError>> pauseSession(
    String sessionId,
  ) async {
    return _apiClient.patch<Map<String, dynamic>>(
      '/api/sessions/$sessionId/pause',
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }

  /// Resumes a paused workout session.
  ///
  /// PATCH /api/sessions/{id}/resume
  Future<Result<Map<String, dynamic>, AppError>> resumeSession(
    String sessionId,
  ) async {
    return _apiClient.patch<Map<String, dynamic>>(
      '/api/sessions/$sessionId/resume',
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }

  /// Skips an exercise in an active session.
  ///
  /// PATCH /api/sessions/{id}/skip-exercise with body: {exercise_id: exerciseId}
  Future<Result<Map<String, dynamic>, AppError>> skipExercise(
    String sessionId,
    String exerciseId,
  ) async {
    return _apiClient.patch<Map<String, dynamic>>(
      '/api/sessions/$sessionId/skip-exercise',
      body: {'exercise_id': exerciseId},
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }

  /// Completes a workout session.
  ///
  /// PATCH /api/sessions/{id}/complete
  /// Returns the full [WorkoutSession] with duration and exercise data.
  Future<Result<WorkoutSession, AppError>> completeSession(
    String sessionId,
  ) async {
    return _apiClient.patch<WorkoutSession>(
      '/api/sessions/$sessionId/complete',
      fromJson: (json) => WorkoutSession.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Generates a new recommendation (weekly plan).
  ///
  /// POST /api/recommendations/generate
  Future<Result<List<Workout>, AppError>> generateRecommendation() async {
    return _apiClient.post<List<Workout>>(
      '/api/recommendations/generate',
      fromJson: (json) => _parseWorkoutsFromRecommendation(json),
    );
  }

  // ─── Timer Support ────────────────────────────────────────────────────

  /// Computes the elapsed active seconds for a session given its start
  /// timestamp and pause log.
  ///
  /// The local timer should call this to synchronize with the backend's
  /// session start timestamp, then increment locally each second.
  static int computeElapsedSeconds({
    required DateTime startedAt,
    required List<Map<String, dynamic>> pauseLog,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final totalElapsed = currentTime.difference(startedAt).inSeconds;

    var totalPaused = 0;
    for (final entry in pauseLog) {
      final pausedAt = DateTime.parse(entry['paused_at'] as String);
      final resumedAtRaw = entry['resumed_at'];
      final resumedAt = resumedAtRaw != null
          ? DateTime.parse(resumedAtRaw as String)
          : currentTime;
      totalPaused += resumedAt.difference(pausedAt).inSeconds;
    }

    return totalElapsed - totalPaused;
  }

  // ─── Private Helpers ──────────────────────────────────────────────────

  /// Parses the workouts array from a recommendation response.
  ///
  /// The recommendation endpoint returns:
  /// ```json
  /// {
  ///   "id": 1,
  ///   "workouts": [
  ///     {"id": 1, "name": "...", "day_of_week": 1, "estimated_duration_minutes": 45, "exercises": [...]}
  ///   ]
  /// }
  /// ```
  List<Workout> _parseWorkoutsFromRecommendation(dynamic json) {
    if (json is Map<String, dynamic>) {
      final workoutsJson = json['workouts'] as List<dynamic>?;
      if (workoutsJson != null) {
        return workoutsJson
            .map((w) => Workout.fromJson(w as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  /// Parses workouts with their day_of_week for matching today's workout.
  List<_WorkoutWithDay> _parseWorkoutsWithDayOfWeek(dynamic json) {
    if (json is Map<String, dynamic>) {
      final workoutsJson = json['workouts'] as List<dynamic>?;
      if (workoutsJson != null) {
        return workoutsJson.map((w) {
          final map = w as Map<String, dynamic>;
          return _WorkoutWithDay(
            workout: Workout.fromJson(map),
            dayOfWeek: map['day_of_week'] as int,
          );
        }).toList();
      }
    }
    return [];
  }

  /// Returns today's day of week as an integer (1 = Monday, 7 = Sunday),
  /// matching the backend's convention.
  int _todayDayOfWeek() {
    return DateTime.now().weekday; // Dart: 1 = Monday, 7 = Sunday
  }
}

/// Internal helper pairing a workout with its day_of_week from the backend.
class _WorkoutWithDay {
  final Workout workout;
  final int dayOfWeek;

  const _WorkoutWithDay({required this.workout, required this.dayOfWeek});
}
