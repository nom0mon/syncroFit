import 'package:uuid/uuid.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../shared/models/models.dart';
import '../local/daos/cache_metadata_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/daos/workout_history_dao.dart';
import '../repositories/workout_history_repository.dart';

/// Cache-aware implementation of [WorkoutHistoryRepository].
///
/// When online:
/// - If cache is fresh (< 15 minutes), serves data from local SQLite.
/// - If cache is stale, fetches from remote, persists to DAO, updates metadata.
///
/// When offline:
/// - Serves data from local SQLite cache.
/// - Queues new workout_history records to the SyncQueue for later sync.
class CachingWorkoutHistoryRepository implements WorkoutHistoryRepository {
  final WorkoutHistoryRepository _remote;
  final WorkoutHistoryDao _dao;
  final CacheMetadataDao _cacheMetadataDao;
  final SyncQueueDao _syncQueueDao;
  final ConnectivityMonitor _connectivity;

  /// Cache freshness threshold in minutes.
  static const int _cacheFreshnessMinutes = 15;

  static const String _entityType = 'workout_history';

  static const _uuid = Uuid();

  CachingWorkoutHistoryRepository({
    required WorkoutHistoryRepository remote,
    required WorkoutHistoryDao dao,
    required CacheMetadataDao cacheMetadataDao,
    required SyncQueueDao syncQueueDao,
    required ConnectivityMonitor connectivity,
  })  : _remote = remote,
        _dao = dao,
        _cacheMetadataDao = cacheMetadataDao,
        _syncQueueDao = syncQueueDao,
        _connectivity = connectivity;

  @override
  Future<Result<List<WorkoutHistory>, AppError>> getAll(String userId) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _dao.getByUser(userId);
        return Success(cached);
      }

      final result = await _remote.getAll(userId);
      if (result is Success<List<WorkoutHistory>, AppError>) {
        // Refresh local cache
        await _dao.deleteAll();
        for (final record in result.value) {
          await _dao.insertRecord(record);
        }
        await _cacheMetadataDao.updateLastSynced(
          _entityType,
          DateTime.now(),
        );
      }
      return result;
    }

    // Offline: serve from cache
    final cached = await _dao.getByUser(userId);
    return Success(cached);
  }

  @override
  Future<Result<List<WorkoutHistory>, AppError>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _dao.getByDateRange(userId, start, end);
        return Success(cached);
      }

      final result = await _remote.getByDateRange(userId, start, end);
      if (result is Success<List<WorkoutHistory>, AppError>) {
        for (final record in result.value) {
          await _dao.insertRecord(record);
        }
        await _cacheMetadataDao.updateLastSynced(
          _entityType,
          DateTime.now(),
        );
      }
      return result;
    }

    // Offline: serve from cache
    final cached = await _dao.getByDateRange(userId, start, end);
    return Success(cached);
  }

  @override
  Future<Result<WorkoutHistory, AppError>> save(WorkoutHistory record) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      final result = await _remote.save(record);
      if (result is Success<WorkoutHistory, AppError>) {
        // Persist the saved record locally
        await _dao.insertRecord(result.value);
      }
      return result;
    }

    // Offline: save locally and enqueue for sync
    await _dao.insertRecord(record);

    final mutation = SyncMutation(
      id: _uuid.v4(),
      entityType: _entityType,
      entityId: record.id,
      operationType: 'create',
      payload: record.toJson(),
      createdAt: DateTime.now(),
    );
    await _syncQueueDao.enqueue(mutation);

    return Success(record);
  }

  // ─── Private Helpers ──────────────────────────────────────────────────

  /// Checks if the workout history cache is still fresh (less than 15 minutes old).
  Future<bool> _isCacheFresh() async {
    final lastSynced = await _cacheMetadataDao.getLastSynced(_entityType);
    if (lastSynced == null) return false;

    final age = DateTime.now().difference(lastSynced);
    return age.inMinutes < _cacheFreshnessMinutes;
  }
}
