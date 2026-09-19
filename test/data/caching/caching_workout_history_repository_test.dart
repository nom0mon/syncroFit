import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchrofit/core/network/connectivity_monitor.dart';
import 'package:synchrofit/data/caching/caching_workout_history_repository.dart';
import 'package:synchrofit/data/local/daos/cache_metadata_dao.dart';
import 'package:synchrofit/data/local/daos/sync_queue_dao.dart';
import 'package:synchrofit/data/local/daos/workout_history_dao.dart';
import 'package:synchrofit/data/repositories/workout_history_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

class _FakeConnectivityMonitor implements ConnectivityMonitor {
  _FakeConnectivityMonitor(this.currentStatus);

  @override
  ConnectivityStatus currentStatus;

  @override
  Stream<ConnectivityStatus> get statusStream => const Stream.empty();

  @override
  Future<bool> checkServerReachability() async =>
      currentStatus == ConnectivityStatus.online;

  @override
  void dispose() {}
}

class _FakeRemoteHistoryRepository implements WorkoutHistoryRepository {
  _FakeRemoteHistoryRepository(this.saveResult);

  final Result<WorkoutHistory, AppError> saveResult;

  @override
  Future<Result<WorkoutHistory, AppError>> save(WorkoutHistory record) async =>
      saveResult;

  @override
  Future<Result<List<WorkoutHistory>, AppError>> getAll(String userId) async =>
      const Success([]);

  @override
  Future<Result<List<WorkoutHistory>, AppError>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async =>
      const Success([]);
}

WorkoutHistory _record() => WorkoutHistory(
      id: 'history-device-1',
      userId: 'user-1',
      workoutName: 'Full Body A',
      completedAt: DateTime(2026, 9, 18, 10),
      totalDurationSeconds: 600,
      exercisesCompleted: const [
        {
          'exercise_id': '1',
          'exercise_name': 'Push-Up',
          'sets_completed': 3,
          'reps_or_duration': 10,
          'is_duration': false,
        },
      ],
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database database;
  late WorkoutHistoryDao historyDao;
  late SyncQueueDao queueDao;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE workout_history (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workout_name TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        total_duration_seconds INTEGER NOT NULL,
        exercises_completed TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await database.execute('''
      CREATE TABLE cache_metadata (
        entity_type TEXT PRIMARY KEY,
        last_synced_at TEXT NOT NULL
      )
    ''');
    historyDao = WorkoutHistoryDao(database);
    queueDao = SyncQueueDao(database);
  });

  tearDown(() => database.close());

  CachingWorkoutHistoryRepository repositoryWith(
    Result<WorkoutHistory, AppError> result,
  ) =>
      CachingWorkoutHistoryRepository(
        remote: _FakeRemoteHistoryRepository(result),
        dao: historyDao,
        cacheMetadataDao: CacheMetadataDao(database),
        syncQueueDao: queueDao,
        connectivity: _FakeConnectivityMonitor(ConnectivityStatus.online),
      );

  test('queues completion when API is unreachable despite online status',
      () async {
    final record = _record();
    final result = await repositoryWith(Failure(NetworkError())).save(record);

    expect(result, isA<Success<WorkoutHistory, AppError>>());
    expect(await historyDao.getByUser(record.userId), contains(record));
    final pending = await queueDao.getPending();
    expect(pending, hasLength(1));
    expect(pending.single.entityType, 'workout_history');
    expect(pending.single.entityId, record.id);
  });

  test('does not queue permanent validation failures', () async {
    final record = _record();
    final result = await repositoryWith(
      Failure(ValidationError(fieldErrors: const {'workout_name': 'Invalid'})),
    ).save(record);

    expect(result, isA<Failure<WorkoutHistory, AppError>>());
    expect(await historyDao.getByUser(record.userId), isEmpty);
    expect(await queueDao.getPending(), isEmpty);
  });
}
