import 'dart:async';

/// The result of processing the sync queue.
class SyncResult {
  final int successful;
  final int failed;
  final int conflicts;
  final List<String> failedMutationIds;

  const SyncResult({
    required this.successful,
    required this.failed,
    required this.conflicts,
    required this.failedMutationIds,
  });
}

/// Events emitted by the [SyncEngine] during synchronization.
enum SyncEvent { started, completed, conflictDetected, mutationFailed }

/// Abstract interface for the background sync engine.
///
/// Listens to connectivity changes and automatically processes pending
/// mutations when the device comes back online. Emits [SyncEvent]s so
/// the UI layer can display sync status indicators.
abstract class SyncEngine {
  /// Start listening for connectivity changes and auto-sync.
  void initialize();

  /// Process all pending mutations in chronological order.
  ///
  /// Called automatically on online transition, but may also be invoked
  /// manually.
  Future<SyncResult> processQueue();

  /// Refresh all local caches from the backend after sync completes.
  ///
  /// If [forceRefresh] is `true`, caches are invalidated first so that the
  /// backend is always queried regardless of cache age.
  Future<void> refreshCaches({bool forceRefresh = false});

  /// Stream of sync events for UI indicators.
  Stream<SyncEvent> get syncEvents;

  /// Release resources (stream subscriptions, timers, etc.).
  void dispose();
}
