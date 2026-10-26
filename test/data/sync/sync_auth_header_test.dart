import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/core/network/connectivity_monitor.dart';
import 'package:synchrofit/core/network/connectivity_provider.dart';
import 'package:synchrofit/core/network/token_storage.dart';
import 'package:synchrofit/data/sync/sync_engine_impl.dart';
import 'package:synchrofit/data/sync/sync_providers.dart';
import 'package:synchrofit/data/sync/sync_queue.dart';
import 'package:synchrofit/shared/models/sync_mutation.dart';

/// Captures outbound requests so the test can assert on headers without a
/// real network call.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      '{"success": true, "data": {}}',
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _OnlineMonitor implements ConnectivityMonitor {
  @override
  ConnectivityStatus get currentStatus => ConnectivityStatus.online;
  @override
  Stream<ConnectivityStatus> get statusStream => const Stream.empty();
  @override
  Future<bool> checkServerReachability() async => true;
  @override
  void dispose() {}
}

/// In-memory sync queue seeded with a single pending profile-create mutation.
class _SeededQueue implements SyncQueue {
  _SeededQueue(this._items);
  final List<SyncMutation> _items;

  @override
  Future<void> enqueue(SyncMutation mutation) async => _items.add(mutation);
  @override
  Future<List<SyncMutation>> getPending() async => List.of(_items);
  @override
  Future<void> markCompleted(String id) async =>
      _items.removeWhere((m) => m.id == id);
  @override
  Future<void> markFailed(String id) async {}
  @override
  Future<void> incrementRetry(String id) async {}
  @override
  Future<int> pendingCount() async => _items.length;
  @override
  Future<void> clear() async => _items.clear();
}

class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage(this._token);
  final String _token;

  @override
  Future<String?> getToken() async => _token;
}

void main() {
  test(
      'sync engine attaches the bearer token to queued profile mutations '
      '(regression: offline-created profiles must sync authenticated)',
      () async {
    final adapter = _CapturingAdapter();
    final seededQueue = _SeededQueue([
      SyncMutation(
        id: 'queue-1',
        entityType: 'profile',
        entityId: 'user-1',
        operationType: 'create',
        payload: const {'first_name': 'Offline', 'last_name': 'User'},
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          _FakeTokenStorage('secret-token'),
        ),
        // Avoid platform plugins (connectivity + sqflite) in a unit test.
        connectivityMonitorProvider.overrideWithValue(_OnlineMonitor()),
        syncQueueProvider.overrideWithValue(seededQueue),
      ],
    );
    addTearDown(container.dispose);

    final engine = container.read(syncEngineProvider) as SyncEngineImpl;
    // Capture the outbound request routed through the engine's real Dio,
    // which includes the auth interceptor wired by syncEngineProvider.
    engine.debugDio.httpClientAdapter = adapter;

    final result = await engine.processQueue();

    expect(result.successful, 1,
        reason: 'authenticated profile create should succeed');
    expect(adapter.lastRequest, isNotNull,
        reason: 'a request should have been sent');
    expect(
      adapter.lastRequest!.headers['Authorization'],
      'Bearer secret-token',
      reason: 'queued mutations must carry the Sanctum bearer token',
    );
    expect(adapter.lastRequest!.path, endsWith('/api/profile'));
  });
}
