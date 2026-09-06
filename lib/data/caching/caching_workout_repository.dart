import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../shared/models/models.dart';
import '../local/daos/cache_metadata_dao.dart';
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
///
/// The Workout model includes embedded exercises (as JSON) and the
/// `isGenerated` flag to distinguish user-created from recommendation-generated
/// workouts.
class CachingWorkoutRepository
    implements WorkoutRepository, WorkoutCustomizationRepository {
  final WorkoutRepository _remote;
  final WorkoutDao _dao;
  final CacheMetadataDao _cacheMetadataDao;
  final ConnectivityMonitor _connectivity;
  final Database _database;
  final String _userId;

  /// Cache freshness threshold in minutes.
  static const int _cacheFreshnessMinutes = 15;

  String get _entityType => 'workout_$_userId';

  CachingWorkoutRepository({
    required WorkoutRepository remote,
    required WorkoutDao dao,
    required CacheMetadataDao cacheMetadataDao,
    required ConnectivityMonitor connectivity,
    required Database database,
    String userId = '',
  })  : _remote = remote,
        _dao = dao,
        _cacheMetadataDao = cacheMetadataDao,
        _connectivity = connectivity,
        _database = database,
        _userId = userId;

  @override
  Future<Result<List<Workout>, AppError>> getAll() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _cachedForUser();
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
    final cached = await _cachedForUser();
    return Success(cached);
  }

  @override
  Future<Result<Workout, AppError>> getById(String id) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _dao.getById(id);
        if (cached != null && (_userId.isEmpty || cached.userId == _userId)) {
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
  Future<Result<Workout, AppError>> customizeExercises(
    String workoutId,
    List<int> exerciseIds,
  ) async {
    if (_connectivity.currentStatus != ConnectivityStatus.online) {
      return Failure(NetworkError());
    }
    final remote = _remote;
    if (remote is! WorkoutCustomizationRepository) {
      return Failure(ServerError(
        statusCode: 0,
        serverMessage: 'Workout customization is unavailable.',
      ));
    }
    final result = await (remote as WorkoutCustomizationRepository)
        .customizeExercises(workoutId, exerciseIds);
    if (result is Success<Workout, AppError>) {
      await _dao.upsert(result.value);
      await _cacheMetadataDao.updateLastSynced(_entityType, DateTime.now());
    }
    return result;
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
      where: _userId.isEmpty
          ? 'day_of_week = ?'
          : 'day_of_week = ? AND user_id = ?',
      whereArgs: _userId.isEmpty
          ? [today.toString()]
          : [today.toString(), _userId],
    );
    if (rows.isEmpty) return null;

    final exercisesJson = rows.first['exercises'] as String;
    final exercisesList = (jsonDecode(exercisesJson) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return Workout.fromJson({
      'id': rows.first['id'],
      'user_id': rows.first['user_id'],
      'name': rows.first['name'],
      'day_of_week': rows.first['day_of_week'],
      'estimated_duration_minutes': rows.first['estimated_duration_minutes'],
      'exercises': exercisesList,
      'is_generated': rows.first['is_generated'],
      'created_at': rows.first['created_at'],
      'updated_at': rows.first['updated_at'],
    });
  }

  Future<List<Workout>> _cachedForUser() async {
    final workouts = await _dao.getAll();
    if (_userId.isEmpty) return workouts;
    return workouts.where((workout) => workout.userId == _userId).toList();
  }
}
