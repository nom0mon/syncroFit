import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/models/workout_history.dart';

/// Data Access Object for workout history records in the local SQLite database.
///
/// Handles CRUD operations for cached workout history data, including JSON
/// encoding of the exercises_completed list and date range queries.
class WorkoutHistoryDao {
  final Database _database;

  WorkoutHistoryDao(this._database);

  static const String _table = 'workout_history';

  /// Inserts a completed workout history record.
  ///
  /// Uses [ConflictAlgorithm.replace] so re-inserting the same record
  /// (by primary key) acts as an upsert.
  Future<void> insertRecord(WorkoutHistory record) async {
    await _database.insert(
      _table,
      _toRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves all workout history records for a given [userId].
  Future<List<WorkoutHistory>> getByUser(String userId) async {
    final rows = await _database.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map(_fromRow).toList();
  }

  /// Retrieves workout history records for a [userId] within a date range.
  ///
  /// The range is inclusive on both [start] and [end]. Comparison is performed
  /// against the `completed_at` column stored as ISO 8601 text.
  Future<List<WorkoutHistory>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _database.query(
      _table,
      where: 'user_id = ? AND completed_at >= ? AND completed_at <= ?',
      whereArgs: [
        userId,
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );
    return rows.map(_fromRow).toList();
  }

  /// Retrieves all workout history records from the local cache.
  Future<List<WorkoutHistory>> getAll() async {
    final rows = await _database.query(_table, orderBy: 'completed_at DESC');
    return rows.map(_fromRow).toList();
  }

  /// Deletes all workout history records from the local cache.
  Future<void> deleteAll() async {
    await _database.delete(_table);
  }

  /// Converts a database row to a [WorkoutHistory] model.
  WorkoutHistory _fromRow(Map<String, dynamic> row) {
    return WorkoutHistory.fromJson({
      'id': row['id'],
      'user_id': row['user_id'],
      'workout_name': row['workout_name'],
      'completed_at': row['completed_at'],
      'total_duration_seconds': row['total_duration_seconds'],
      'exercises_completed': row['exercises_completed'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    });
  }

  /// Converts a [WorkoutHistory] model to a database row map.
  ///
  /// The `exercises_completed` list is JSON-encoded for SQLite storage.
  Map<String, dynamic> _toRow(WorkoutHistory record) {
    return {
      'id': record.id,
      'user_id': record.userId,
      'workout_name': record.workoutName,
      'completed_at': record.completedAt.toIso8601String(),
      'total_duration_seconds': record.totalDurationSeconds,
      'exercises_completed': jsonEncode(record.exercisesCompleted),
      'created_at': record.createdAt?.toIso8601String(),
      'updated_at': record.updatedAt?.toIso8601String(),
    };
  }
}
