import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_config.dart';
import '../../core/network/connectivity_provider.dart';
import '../../shared/models/sync_mutation.dart';
import '../local/database_provider.dart';
import 'conflict_resolver.dart';
import 'sync_engine.dart';
import 'sync_engine_impl.dart';
import 'sync_queue.dart';
import 'sync_queue_impl.dart';

/// A no-op [SyncQueue] for when the database is not available (e.g., web).
class _NoOpSyncQueue implements SyncQueue {
  @override
  Future<void> enqueue(SyncMutation mutation) async {}
  @override
  Future<List<SyncMutation>> getPending() async => [];
  @override
  Future<void> markCompleted(String mutationId) async {}
  @override
  Future<void> markFailed(String mutationId) async {}
  @override
  Future<void> incrementRetry(String mutationId) async {}
  @override
  Future<int> pendingCount() async => 0;
  @override
  Future<void> clear() async {}
}

/// A no-op [SyncEngine] for when the database/sync is not available (e.g., web).
class _NoOpSyncEngine implements SyncEngine {
  @override
  void initialize() {}
  @override
  Future<SyncResult> processQueue() async => const SyncResult(
      successful: 0, failed: 0, conflicts: 0, failedMutationIds: []);
  @override
  Future<void> refreshCaches({bool forceRefresh = false}) async {}
  @override
  Stream<SyncEvent> get syncEvents => const Stream.empty();
  @override
  void dispose() {}
}

/// Provides the [SyncQueue] backed by the local database's SyncQueueDao.
/// Returns a no-op implementation when the database is not available.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  try {
    final db = ref.watch(localDatabaseProvider);
    return SyncQueueImpl(db.syncQueueDao);
  } catch (e) {
    return _NoOpSyncQueue();
  }
});

/// Provides the [ConflictResolver] (stateless, last-write-wins strategy).
final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver();
});

/// Provides the [SyncEngine] and calls `initialize()` to start listening
/// for connectivity changes.
/// Returns a no-op implementation when dependencies are not available.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  try {
    final syncQueue = ref.watch(syncQueueProvider);
    final conflictResolver = ref.watch(conflictResolverProvider);
    final connectivityMonitor = ref.watch(connectivityMonitorProvider);

    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.timeout,
        receiveTimeout: ApiConfig.timeout,
        sendTimeout: ApiConfig.timeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    final engine = SyncEngineImpl(
      syncQueue: syncQueue,
      conflictResolver: conflictResolver,
      connectivityMonitor: connectivityMonitor,
      dio: dio,
      onRefreshCaches: ({bool forceRefresh = false}) async {
        try {
          final db = ref.read(localDatabaseProvider);
          if (forceRefresh) {
            // Invalidate all cache metadata so subsequent fetches
            // always hit the backend regardless of cache age.
            final cacheKeys = ['exercises', 'workouts', 'profile', 'progress'];
            for (final key in cacheKeys) {
              await db.cacheMetadataDao.updateLastSynced(
                key,
                DateTime(2000, 1, 1),
              );
            }
          }
        } catch (_) {
          // Database not available on this platform
        }
      },
    );

    engine.initialize();

    ref.onDispose(() {
      engine.dispose();
    });

    return engine;
  } catch (e) {
    return _NoOpSyncEngine();
  }
});

/// State exposed by [SyncStatusNotifier] for UI consumption.
class SyncStatusState {
  /// Whether the sync engine is currently processing the queue.
  final bool isSyncing;

  /// Number of mutations pending in the queue.
  final int pendingCount;

  /// The last sync event received from the engine.
  final SyncEvent? lastEvent;

  /// The last result from a completed sync cycle.
  final SyncResult? lastSyncResult;

  const SyncStatusState({
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastEvent,
    this.lastSyncResult,
  });

  SyncStatusState copyWith({
    bool? isSyncing,
    int? pendingCount,
    SyncEvent? lastEvent,
    SyncResult? lastSyncResult,
  }) {
    return SyncStatusState(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastEvent: lastEvent ?? this.lastEvent,
      lastSyncResult: lastSyncResult ?? this.lastSyncResult,
    );
  }
}

/// StateNotifier that listens to [SyncEngine.syncEvents] and the [SyncQueue]
/// to expose sync status for UI widgets (offline indicator, pending badge, etc.).
class SyncStatusNotifier extends StateNotifier<SyncStatusState> {
  SyncStatusNotifier({
    required SyncEngine syncEngine,
    required SyncQueue syncQueue,
  })  : _syncEngine = syncEngine,
        _syncQueue = syncQueue,
        super(const SyncStatusState()) {
    _subscription = _syncEngine.syncEvents.listen(_onSyncEvent);
    _refreshPendingCount();
  }

  final SyncEngine _syncEngine;
  final SyncQueue _syncQueue;
  StreamSubscription<SyncEvent>? _subscription;

  void _onSyncEvent(SyncEvent event) {
    switch (event) {
      case SyncEvent.started:
        state = state.copyWith(isSyncing: true, lastEvent: event);
        break;
      case SyncEvent.completed:
        state = state.copyWith(isSyncing: false, lastEvent: event);
        _refreshPendingCount();
        break;
      case SyncEvent.conflictDetected:
      case SyncEvent.mutationFailed:
        state = state.copyWith(lastEvent: event);
        _refreshPendingCount();
        break;
    }
  }

  /// Refreshes the pending mutation count from the sync queue.
  Future<void> _refreshPendingCount() async {
    final count = await _syncQueue.pendingCount();
    if (mounted) {
      state = state.copyWith(pendingCount: count);
    }
  }

  /// Manually triggers a pending count refresh (e.g., after enqueueing a
  /// new mutation from a caching repository).
  Future<void> refreshPendingCount() async {
    await _refreshPendingCount();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provides the current [SyncStatusState] for UI widgets.
///
/// Usage:
/// ```dart
/// final status = ref.watch(syncStatusProvider);
/// if (status.isSyncing) { showSpinner(); }
/// if (status.pendingCount > 0) { showBadge(status.pendingCount); }
/// ```
final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatusState>((ref) {
  final syncEngine = ref.watch(syncEngineProvider);
  final syncQueue = ref.watch(syncQueueProvider);
  return SyncStatusNotifier(
    syncEngine: syncEngine,
    syncQueue: syncQueue,
  );
});
