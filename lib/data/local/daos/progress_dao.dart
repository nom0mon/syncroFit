import 'package:sqflite/sqflite.dart';

import '../../../shared/models/progress_record.dart';

/// Data Access Object for progress records in the local SQLite database.
///
/// Handles CRUD operations for cached progress tracking data.
class ProgressDao {
  final Database _database;

  ProgressDao(this._database);

  static const String _table = 'progress_records';

  /// Retrieves all cached progress records.
  Future<List<ProgressRecord>> getAll() async {
    final rows = await _database.query(_table);
    return rows.map(_fromRow).toList();
  }

  /// Inserts or updates a single progress record.
  Future<void> upsert(ProgressRecord record) async {
    await _database.insert(
      _table,
      _toRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts or updates a list of progress records in a single batch.
  Future<void> upsertAll(List<ProgressRecord> records) async {
    final batch = _database.batch();
    for (final record in records) {
      batch.insert(
        _table,
        _toRow(record),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Deletes a progress record by its ID.
  Future<void> deleteById(String id) async {
    await _database.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Converts a database row to a [ProgressRecord] model.
  ProgressRecord _fromRow(Map<String, dynamic> row) {
    return ProgressRecord.fromJson({
      'id': row['id'],
      'recorded_at': row['recorded_at'],
      'weight_kg': row['weight_kg'],
      'bmi': row['bmi'],
      'workouts_completed': row['workouts_completed'],
    });
  }

  /// Converts a [ProgressRecord] model to a database row map.
  Map<String, dynamic> _toRow(ProgressRecord record) {
    return {
      'id': record.id,
      'recorded_at': record.date.toIso8601String(),
      'weight_kg': record.weightKg,
      'bmi': record.bmi,
      'workouts_completed': record.workoutsCompleted,
    };
  }
}
