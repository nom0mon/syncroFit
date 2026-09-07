import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/core/network/connectivity_monitor.dart';
import 'package:synchrofit/data/sync/conflict_resolver.dart';
import 'package:synchrofit/data/sync/sync_engine_impl.dart';
import 'package:synchrofit/data/sync/sync_queue.dart';
import 'package:synchrofit/shared/models/sync_mutation.dart';

class _MockDio extends Mock implements Dio {}

class _MemoryQueue implements SyncQueue {
  _MemoryQueue(this.items);
  final List<SyncMutation> items;

  @override
  Future<void> enqueue(SyncMutation mutation) async => items.add(mutation);
  @override
  Future<List<SyncMutation>> getPending() async => List.of(items);
  @override
  Future<void> markCompleted(String mutationId) async =>
      items.removeWhere((item) => item.id == mutationId);
  @override
  Future<void> markFailed(String mutationId) async {}
  @override
  Future<void> incrementRetry(String mutationId) async {}
  @override
  Future<int> pendingCount() async => items.length;
  @override
  Future<void> clear() async => items.clear();
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

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '')));

  test('workout-history replay carries a stable client mutation id', () async {
    final mutation = SyncMutation(
      id: 'queue-1',
      entityType: 'workout_history',
      entityId: 'history-device-123',
      operationType: 'create',
      payload: const {'workout_name': 'Full Body A'},
      createdAt: DateTime.utc(2026, 9, 7),
    );
    final queue = _MemoryQueue([mutation]);
    final dio = _MockDio();
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (invocation) async => Response(
        requestOptions:
            RequestOptions(path: invocation.positionalArguments[0] as String),
        statusCode: 201,
      ),
    );
    final engine = SyncEngineImpl(
      syncQueue: queue,
      conflictResolver: ConflictResolver(),
      connectivityMonitor: _OnlineMonitor(),
      dio: dio,
    );
    addTearDown(engine.dispose);

    final result = await engine.processQueue();

    expect(result.successful, 1);
    expect(queue.items, isEmpty);
    final captured = verify(() => dio.post(
          captureAny(),
          data: captureAny(named: 'data'),
        )).captured;
    expect(captured[0] as String, endsWith('/api/workout-history'));
    expect(
      (captured[1] as Map<String, dynamic>)['client_mutation_id'],
      'history-device-123',
    );
  });

  test('queued profile updates use the real singleton PUT endpoint', () async {
    final queue = _MemoryQueue([
      SyncMutation(
        id: 'queue-2',
        entityType: 'profile',
        entityId: '42',
        operationType: 'update',
        payload: const {'weight_kg': 75.0},
        createdAt: DateTime.utc(2026, 9, 7),
      ),
    ]);
    final dio = _MockDio();
    when(() => dio.put(any(), data: any(named: 'data'))).thenAnswer(
      (invocation) async => Response(
        requestOptions:
            RequestOptions(path: invocation.positionalArguments[0] as String),
        statusCode: 200,
      ),
    );
    final engine = SyncEngineImpl(
      syncQueue: queue,
      conflictResolver: ConflictResolver(),
      connectivityMonitor: _OnlineMonitor(),
      dio: dio,
    );
    addTearDown(engine.dispose);

    expect((await engine.processQueue()).successful, 1);
    verify(() => dio.put(
          any(that: endsWith('/api/profile')),
          data: {'weight_kg': 75.0},
        )).called(1);
    verifyNever(() => dio.patch(any(), data: any(named: 'data')));
  });
}
