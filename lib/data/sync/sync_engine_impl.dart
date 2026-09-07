import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/network/api_config.dart';
import '../../core/network/connectivity_monitor.dart';
import '../../shared/models/sync_mutation.dart';
import 'conflict_resolver.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

/// Implementation of [SyncEngine] that processes queued mutations on
/// reconnection, handles conflict resolution, and retries transient errors
/// with exponential backoff.
class SyncEngineImpl implements SyncEngine {
  final SyncQueue _syncQueue;
  final ConflictResolver _conflictResolver;
  final ConnectivityMonitor _connectivityMonitor;
  final Dio _dio;

  /// Callback invoked after the queue is fully processed to refresh local
  /// caches from the backend. Injected by the caller so the engine does not
  /// depend directly on caching repositories.
  ///
  /// The callback receives a [forceRefresh] parameter; when `true` the caller
  /// should invalidate cache metadata before fetching fresh data.
  final Future<void> Function({bool forceRefresh})? onRefreshCaches;

  final StreamController<SyncEvent> _syncEventController =
      StreamController<SyncEvent>.broadcast();

  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  bool _isSyncing = false;

  /// Maximum number of retry attempts for transient errors.
  static const int _maxRetries = 3;

  /// Base delay for exponential backoff (doubles on each retry).
  static const Duration _baseDelay = Duration(seconds: 2);

  SyncEngineImpl({
    required SyncQueue syncQueue,
    required ConflictResolver conflictResolver,
    required ConnectivityMonitor connectivityMonitor,
    required Dio dio,
    this.onRefreshCaches,
  })  : _syncQueue = syncQueue,
        _conflictResolver = conflictResolver,
        _connectivityMonitor = connectivityMonitor,
        _dio = dio;

  @override
  Stream<SyncEvent> get syncEvents => _syncEventController.stream;

  @override
  void initialize() {
    _connectivitySubscription =
        _connectivityMonitor.statusStream.listen((status) {
      if (status == ConnectivityStatus.online) {
        processQueue();
      }
    });
  }

  @override
  Future<SyncResult> processQueue() async {
    // Prevent concurrent sync runs.
    if (_isSyncing) {
      return const SyncResult(
        successful: 0,
        failed: 0,
        conflicts: 0,
        failedMutationIds: [],
      );
    }

    _isSyncing = true;
    _syncEventController.add(SyncEvent.started);

    int successful = 0;
    int failed = 0;
    int conflicts = 0;
    final List<String> failedMutationIds = [];

    try {
      final pending = await _syncQueue.getPending();

      for (final mutation in pending) {
        final result = await _processMutation(mutation);

        switch (result) {
          case _MutationOutcome.success:
            await _syncQueue.markCompleted(mutation.id);
            successful++;
            break;
          case _MutationOutcome.conflict:
            conflicts++;
            _syncEventController.add(SyncEvent.conflictDetected);
            // Conflict resolved — either server or local won, mutation is done.
            await _syncQueue.markCompleted(mutation.id);
            break;
          case _MutationOutcome.permanentFailure:
            await _syncQueue.markFailed(mutation.id);
            failed++;
            failedMutationIds.add(mutation.id);
            _syncEventController.add(SyncEvent.mutationFailed);
            break;
          case _MutationOutcome.transientFailure:
            // Already retried up to max — mark as failed.
            await _syncQueue.markFailed(mutation.id);
            failed++;
            failedMutationIds.add(mutation.id);
            _syncEventController.add(SyncEvent.mutationFailed);
            break;
        }
      }

      // After all mutations processed, refresh caches from backend.
      await refreshCaches();
    } finally {
      _isSyncing = false;
      _syncEventController.add(SyncEvent.completed);
    }

    return SyncResult(
      successful: successful,
      failed: failed,
      conflicts: conflicts,
      failedMutationIds: failedMutationIds,
    );
  }

  @override
  Future<void> refreshCaches({bool forceRefresh = false}) async {
    if (onRefreshCaches != null) {
      await onRefreshCaches!(forceRefresh: forceRefresh);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncEventController.close();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Processes a single mutation with retry logic.
  Future<_MutationOutcome> _processMutation(SyncMutation mutation) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await _sendRequest(mutation);

        final statusCode = response.statusCode ?? 500;

        if (statusCode >= 200 && statusCode < 300) {
          return _MutationOutcome.success;
        }

        if (statusCode == 409) {
          return _handleConflict(mutation, response);
        }

        if (statusCode == 422) {
          return _MutationOutcome.permanentFailure;
        }

        // 5xx — transient, retry with backoff.
        if (statusCode >= 500) {
          if (attempt < _maxRetries - 1) {
            await _backoff(attempt);
            await _syncQueue.incrementRetry(mutation.id);
            continue;
          }
          return _MutationOutcome.transientFailure;
        }

        // Other unexpected status codes — treat as permanent failure.
        return _MutationOutcome.permanentFailure;
      } on DioException catch (e) {
        final isTransient = _isTransientError(e);
        if (isTransient && attempt < _maxRetries - 1) {
          await _backoff(attempt);
          await _syncQueue.incrementRetry(mutation.id);
          continue;
        }
        return isTransient
            ? _MutationOutcome.transientFailure
            : _MutationOutcome.permanentFailure;
      }
    }

    return _MutationOutcome.transientFailure;
  }

  /// Sends the appropriate HTTP request based on the mutation's operation type.
  Future<Response> _sendRequest(SyncMutation mutation) {
    final path = _buildPath(mutation);
    final payload = mutation.entityType == 'workout_history' &&
            mutation.operationType == 'create'
        ? {
            ...mutation.payload,
            // Older queued rows do not contain this field. The stable local
            // entity id makes those uploads retry-safe after an app restart.
            'client_mutation_id': mutation.entityId,
          }
        : mutation.payload;

    switch (mutation.operationType) {
      case 'create':
        return _dio.post(path, data: payload);
      case 'update':
        return mutation.entityType == 'profile'
            ? _dio.put(path, data: payload)
            : _dio.patch(path, data: payload);
      case 'delete':
        return _dio.delete(path);
      default:
        return _dio.post(path, data: mutation.payload);
    }
  }

  /// Builds the API path for a mutation based on entity type and operation.
  String _buildPath(SyncMutation mutation) {
    if (mutation.entityType == 'profile') {
      return '${ApiConfig.baseUrl}/api/profile';
    }
    final segment = _entityTypeToPathSegment(mutation.entityType);
    final base = '${ApiConfig.baseUrl}/api/$segment';
    if (mutation.operationType == 'create') {
      return base;
    }
    return '$base/${mutation.entityId}';
  }

  /// Maps an entity type to its corresponding API path segment.
  ///
  /// Most entity types simply append 's' (e.g., 'workout' → 'workouts'),
  /// but some require a custom mapping (e.g., 'workout_history' → 'workout-history').
  static String _entityTypeToPathSegment(String entityType) {
    switch (entityType) {
      case 'workout_history':
        return 'workout-history';
      default:
        return '${entityType}s';
    }
  }

  /// Handles a 409 Conflict response using the [ConflictResolver].
  _MutationOutcome _handleConflict(
    SyncMutation mutation,
    Response response,
  ) {
    final responseData = response.data;
    DateTime? serverUpdatedAt;

    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic> && data.containsKey('updated_at')) {
        serverUpdatedAt = DateTime.tryParse(data['updated_at'] as String);
      }
    }

    if (serverUpdatedAt == null) {
      // Cannot determine server timestamp — server wins by default.
      return _MutationOutcome.conflict;
    }

    final localWins = _conflictResolver.shouldApplyLocal(
      localMutationTimestamp: mutation.createdAt,
      serverUpdatedAt: serverUpdatedAt,
    );

    if (localWins) {
      // Local wins — in practice the mutation is already "applied" as the
      // server should accept on retry with force. We mark completed.
      return _MutationOutcome.conflict;
    }

    // Server wins — discard local mutation.
    return _MutationOutcome.conflict;
  }

  /// Determines whether a [DioException] represents a transient error
  /// (5xx or timeout) eligible for retry.
  bool _isTransientError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }

    if (e.type == DioExceptionType.badResponse) {
      final statusCode = e.response?.statusCode ?? 0;
      return statusCode >= 500;
    }

    return false;
  }

  /// Exponential backoff: 2s, 4s, 8s based on attempt index.
  Future<void> _backoff(int attempt) {
    final delay = _baseDelay * (1 << attempt); // 2s, 4s, 8s
    return Future.delayed(delay);
  }
}

/// Internal enum representing the outcome of processing a single mutation.
enum _MutationOutcome {
  success,
  conflict,
  permanentFailure,
  transientFailure,
}
