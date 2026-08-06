import 'package:sqflite/sqflite.dart';

import '../../../shared/models/sync_mutation.dart';

/// Data Access Object for the sync queue in the local SQLite database.
///
/// Manages queued mutations that need to be synced with the backend
/// when connectivity is restored. Mutations are processed in FIFO
/// order based on their creation timestamp.
class SyncQueueDao {
  final Database _database;

  SyncQueueDao(this._database);

  static const String _table = 'sync_queue';

  /// Enqueues a new mutation for later sync.
  Future<void> enqueue(SyncMutation mutation) async {
    await _database.insert(
      _table,
      mutation.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves all pending mutations ordered by creation time (oldest first).
  Future<List<SyncMutation>> getPending() async {
    final rows = await _database.query(
      _table,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => SyncMutation.fromJson(row)).toList();
  }

  /// Marks a mutation as successfully synced and removes it from the queue.
  Future<void> markCompleted(String mutationId) async {
    await _database.delete(
      _table,
      where: 'id = ?',
      whereArgs: [mutationId],
    );
  }

  /// Marks a mutation as permanently failed.
  Future<void> markFailed(String mutationId) async {
    await _database.update(
      _table,
      {'status': 'failed'},
      where: 'id = ?',
      whereArgs: [mutationId],
    );
  }

  /// Increments the retry count for a mutation and sets status to pending.
  Future<void> incrementRetry(String mutationId) async {
    await _database.rawUpdate(
      'UPDATE $_table SET retry_count = retry_count + 1, status = ? WHERE id = ?',
      ['pending', mutationId],
    );
  }

  /// Returns the count of pending mutations in the queue.
  Future<int> pendingCount() async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM $_table WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Removes all mutations from the sync queue.
  Future<void> clear() async {
    await _database.delete(_table);
  }
}
