import '../../shared/models/sync_mutation.dart';
import '../local/daos/sync_queue_dao.dart';
import 'sync_queue.dart';

/// Implementation of [SyncQueue] that delegates all operations
/// to [SyncQueueDao].
///
/// This thin service layer exists so other components depend on the
/// abstract [SyncQueue] interface rather than the DAO directly,
/// enabling easier testing and future flexibility.
class SyncQueueImpl implements SyncQueue {
  final SyncQueueDao _dao;

  SyncQueueImpl(this._dao);

  @override
  Future<void> enqueue(SyncMutation mutation) => _dao.enqueue(mutation);

  @override
  Future<List<SyncMutation>> getPending() => _dao.getPending();

  @override
  Future<void> markCompleted(String mutationId) =>
      _dao.markCompleted(mutationId);

  @override
  Future<void> markFailed(String mutationId) => _dao.markFailed(mutationId);

  @override
  Future<void> incrementRetry(String mutationId) =>
      _dao.incrementRetry(mutationId);

  @override
  Future<int> pendingCount() => _dao.pendingCount();

  @override
  Future<void> clear() => _dao.clear();
}
