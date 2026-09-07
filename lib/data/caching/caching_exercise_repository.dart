import 'package:synchrofit/core/network/connectivity_monitor.dart';
import 'package:synchrofit/data/local/daos/cache_metadata_dao.dart';
import 'package:synchrofit/data/local/daos/exercise_dao.dart';
import 'package:synchrofit/data/repositories/exercise_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Caching decorator for [ExerciseRepository] that transparently adds offline
/// persistence and cache freshness logic.
///
/// Online behaviour:
/// - If the cache is less than [_cacheMaxAge] old, serves from the local DAO.
/// - If the cache is stale or missing, fetches from the remote repository,
///   persists results to the DAO, and updates cache metadata.
///
/// Offline behaviour:
/// - Always serves from the local DAO.
class CachingExerciseRepository implements ExerciseRepository {
  final ExerciseRepository _remote;
  final ExerciseDao _dao;
  final CacheMetadataDao _cacheMetadataDao;
  final ConnectivityMonitor _connectivity;

  static const Duration _cacheMaxAge = Duration(minutes: 15);
  static const String _cacheKey = 'exercises';

  CachingExerciseRepository({
    required ExerciseRepository remote,
    required ExerciseDao dao,
    required CacheMetadataDao cacheMetadataDao,
    required ConnectivityMonitor connectivity,
  })  : _remote = remote,
        _dao = dao,
        _cacheMetadataDao = cacheMetadataDao,
        _connectivity = connectivity;

  // ─────────────────────────────────────────────────────────────────────────
  // ExerciseRepository implementation
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<Result<List<Exercise>, AppError>> getAll() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _dao.getAll();
        return Success(cached);
      }
      // Cache stale or missing — fetch from remote
      final result = await _remote.getAll();
      if (result is Success<List<Exercise>, AppError>) {
        await _dao.upsertAll(result.value);
        await _cacheMetadataDao.updateLastSynced(_cacheKey, DateTime.now());
      }
      return result;
    }
    // Offline: serve from cache
    final cached = await _dao.getAll();
    return Success(cached);
  }

  @override
  Future<Result<Exercise, AppError>> getById(String id) async {
    // Always check local cache first
    final cached = await _dao.getById(id);
    if (cached != null) {
      return Success(cached);
    }

    // Not in cache — if online, fetch from remote
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      final result = await _remote.getById(id);
      if (result is Success<Exercise, AppError>) {
        await _dao.upsert(result.value);
      }
      return result;
    }

    // Offline and not in cache
    return Failure(NotFoundError(entityType: 'Exercise', id: id));
  }

  @override
  Future<Result<List<Exercise>, AppError>> search(String query) async {
    final allResult = await _getAllWithCacheStrategy();
    switch (allResult) {
      case Success(value: final exercises):
        final filtered = exercises
            .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
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
    final allResult = await _getAllWithCacheStrategy();
    switch (allResult) {
      case Success(value: final exercises):
        final lowerGroups = groups.map((g) => g.toLowerCase()).toList();
        final filtered = exercises
            .where((e) => lowerGroups.contains(e.muscleGroup.toLowerCase()))
            .toList();
        return Success(filtered);
      case Failure(error: final error):
        return Failure(error);
    }
  }

  @override
  Future<Result<List<Exercise>, AppError>> filterByDifficulty(
    String difficulty,
  ) async {
    final allResult = await _getAllWithCacheStrategy();
    switch (allResult) {
      case Success(value: final exercises):
        final filtered = exercises
            .where((e) =>
                e.difficulty.name.toLowerCase() == difficulty.toLowerCase())
            .toList();
        return Success(filtered);
      case Failure(error: final error):
        return Failure(error);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Shared strategy used by search/filter methods:
  /// - Online + fresh cache → serve from DAO
  /// - Online + stale cache → fetch all from remote, persist, then serve
  /// - Offline → serve from DAO
  Future<Result<List<Exercise>, AppError>> _getAllWithCacheStrategy() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _dao.getAll();
        return Success(cached);
      }
      // Cache stale — refresh from remote
      final result = await _remote.getAll();
      if (result is Success<List<Exercise>, AppError>) {
        await _dao.upsertAll(result.value);
        await _cacheMetadataDao.updateLastSynced(_cacheKey, DateTime.now());
      }
      return result;
    }
    // Offline
    final cached = await _dao.getAll();
    return Success(cached);
  }

  /// Returns `true` if the cache was last synced less than [_cacheMaxAge] ago.
  Future<bool> _isCacheFresh() async {
    final lastSynced = await _cacheMetadataDao.getLastSynced(_cacheKey);
    if (lastSynced == null) return false;
    return DateTime.now().difference(lastSynced) < _cacheMaxAge;
  }
}
