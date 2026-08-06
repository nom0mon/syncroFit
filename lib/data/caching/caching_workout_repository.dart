import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../shared/models/models.dart';
import '../local/daos/cache_metadata_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/daos/workout_dao.dart';
import '../repositories/workout_repository.dart';

/// Cache-aware implementation of [WorkoutRepository].
///
/// When online:
/// - If cache is fresh (< 15 minutes), serves data from local SQLite.
/// - If cache is stale, fetches from remote, persists to DAO, updates metadata.
///
/// When offline:
/// - Serves data from local SQLite cache.
/// - Queues mutations (e.g., saveSession) to the SyncQueue for later sync.
class CachingWorkoutRepository implements WorkoutRepository {
  final WorkoutRepository _remote;
  final WorkoutDao _dao;
  final CacheMetadataDao _cacheMetadataDao;
  final SyncQueueDao _syncQueueDao;
  final ConnectivityMonitor _connectivity;
  final Database _database;

  /// Cache freshness threshold in minutes.
  static const int _cacheFreshnessMinutes = 15;

  static const String _entityType = 'workout';
  static const String _sessionsTable = 'workout_sessions';

  static const _uuid = Uuid();

  CachingWorkoutRepository({
    required WorkoutRepository remote,
    required WorkoutDao dao,
    required CacheMetadataDao cacheMetadataDao,
    required SyncQueueDao syncQueueDao,
    required ConnectivityMonitor connectivity,
    required Database database,
  })  : _remote = remote,
        _dao = dao,
        _cacheMetadataDao = cacheMetadataDao,
        _syncQueueDao = syncQueueDao,
        _connectivity = connectivity,
        _database = database;

  @override
  Future<Result<List<Workout>, AppError>> getAll() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _dao.getAll();
        return Success(cached);
      }

      final result = await _remote.getAll();
      if (result is Success<List<Workout>, AppError>) {
        await _dao.upsertAll(result.value);
        await _cacheMetadataDao.updateLastSynced(
          _entityType,
          DateTime.now(),
        );
      }
      return result;
    }

    // Offline: serve from cache
    final cached = await _dao.getAll();
    return Success(cached);
  }

  @override
  Future<Result<Workout, AppError>> getById(String id) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _dao.getById(id);
        if (cached != null) {
          return Success(cached);
        }
      }

      final result = await _remote.getById(id);
      if (result is Success<Workout, AppError>) {
        await _dao.upsert(result.value);
      }
      return result;
    }

    // Offline: serve from cache
    final cached = await _dao.getById(id);
    if (cached == null) {
      return Failure(NotFoundError(entityType: 'Workout', id: id));
    }
    return Success(cached);
  }

  @override
  Future<Result<Workout?, AppError>> getTodaysWorkout() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        // Try to find today's workout from the cache
        final todayWorkout = await _getTodaysWorkoutFromCache();
        if (todayWorkout != null) {
          return Success(todayWorkout);
        }
      }

      final result = await _remote.getTodaysWorkout();
      if (result is Success<Workout?, AppError> && result.value != null) {
        await _dao.upsert(result.value!);
      }
      return result;
    }

    // Offline: try to serve from cache
    final todayWorkout = await _getTodaysWorkoutFromCache();
    return Success(todayWorkout);
  }

  @override
  Future<Result<List<WorkoutSession>, AppError>> getSessionHistory() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _getSessionsFromCache();
        return Success(cached);
      }

      final result = await _remote.getSessionHistory();
      if (result is Success<List<WorkoutSession>, AppError>) {
        await _persistSessions(result.value);
        await _cacheMetadataDao.updateLastSynced(
          'workout_session',
          DateTime.now(),
        );
      }
      return result;
    }

    // Offline: serve from cache
    final cached = await _getSessionsFromCache();
    return Success(cached);
  }

  @override
  Future<Result<WorkoutSession, AppError>> saveSession(
    WorkoutSession session,
  ) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      final result = await _remote.saveSession(session);
      if (result is Success<WorkoutSession, AppError>) {
        // Persist the saved session locally
        await _persistSession(result.value);
      }
      return result;
    }

    // Offline: save locally and enqueue for sync
    await _persistSession(session);

    final mutation = SyncMutation(
      id: _uuid.v4(),
      entityType: _entityType,
      entityId: session.id,
      operationType: 'create',
      payload: session.toJson(),
      createdAt: DateTime.now(),
    );
    await _syncQueueDao.enqueue(mutation);

    return Success(session);
  }

  // ─── Private Helpers ──────────────────────────────────────────────────

  /// Checks if the workout cache is still fresh (less than 15 minutes old).
  Future<bool> _isCacheFresh() async {
    final lastSynced = await _cacheMetadataDao.getLastSynced(_entityType);
    if (lastSynced == null) return false;

    final age = DateTime.now().difference(lastSynced);
    return age.inMinutes < _cacheFreshnessMinutes;
  }

  /// Attempts to find today's workout from the local cache.
  ///
  /// Looks for a workout with a matching `day_of_week` value in the database.
  Future<Workout?> _getTodaysWorkoutFromCache() async {
    final today = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    final rows = await _database.query(
      'workouts',
      where: 'day_of_week = ?',
      whereArgs: [today.toString()],
    );
    if (rows.isEmpty) return null;

    final exercisesJson = rows.first['exercises'] as String;
    final exercisesList = (jsonDecode(exercisesJson) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return Workout.fromJson({
      'id': rows.first['id'],
      'name': rows.first['name'],
      'estimated_duration_minutes': rows.first['estimated_duration_minutes'],
      'exercises': exercisesList,
    });
  }

  /// Retrieves all workout sessions from the local cache.
  Future<List<WorkoutSession>> _getSessionsFromCache() async {
    final rows = await _database.query(
      _sessionsTable,
      orderBy: 'completed_at DESC',
    );
    return rows.map(_sessionFromRow).toList();
  }

  /// Persists a list of workout sessions to the local cache.
  Future<void> _persistSessions(List<WorkoutSession> sessions) async {
    final batch = _database.batch();
    for (final session in sessions) {
      batch.insert(
        _sessionsTable,
        _sessionToRow(session),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Persists a single workout session to the local cache.
  Future<void> _persistSession(WorkoutSession session) async {
    await _database.insert(
      _sessionsTable,
      _sessionToRow(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Converts a database row to a [WorkoutSession].
  WorkoutSession _sessionFromRow(Map<String, dynamic> row) {
    final exercisesJson = row['exercises'] as String;
    final exercisesList = (jsonDecode(exercisesJson) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return WorkoutSession.fromJson({
      'id': row['id'],
      'workout_id': row['workout_id'],
      'workout_name': row['workout_name'],
      'completed_at': row['completed_at'],
      'total_duration_seconds': row['total_duration_seconds'],
      'exercises_completed': row['exercises_completed'],
      'exercises': exercisesList,
    });
  }

  /// Converts a [WorkoutSession] to a database row map.
  Map<String, dynamic> _sessionToRow(WorkoutSession session) {
    return {
      'id': session.id,
      'workout_id': session.workoutId,
      'workout_name': session.workoutName,
      'completed_at': session.completedAt.toIso8601String(),
      'total_duration_seconds': session.totalDurationSeconds,
      'exercises_completed': session.exercisesCompleted,
      'exercises': jsonEncode(
        session.exercises.map((e) => e.toJson()).toList(),
      ),
    };
  }
}
