import '../../shared/models/sync_mutation.dart';

/// Abstract interface for the sync mutation queue.
///
/// Provides operations to enqueue, retrieve, and manage mutations
/// that are pending synchronization with the backend. Components
/// depend on this interface rather than the DAO directly.
abstract class SyncQueue {
  /// Enqueues a new mutation for later sync.
  Future<void> enqueue(SyncMutation mutation);

  /// Retrieves all pending mutations ordered by [createdAt] ascending.
  Future<List<SyncMutation>> getPending();

  /// Marks a mutation as successfully synced and removes it from the queue.
  Future<void> markCompleted(String mutationId);

  /// Marks a mutation as permanently failed.
  Future<void> markFailed(String mutationId);

  /// Increments the retry count for a mutation and resets status to pending.
  Future<void> incrementRetry(String mutationId);

  /// Returns the count of pending mutations in the queue.
  Future<int> pendingCount();

  /// Removes all mutations from the sync queue.
  Future<void> clear();
}
