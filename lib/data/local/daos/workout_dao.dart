import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../shared/models/workout.dart';

/// Data Access Object for workouts in the local SQLite database.
///
/// Handles CRUD operations for cached workout data, including JSON encoding
/// of the exercises list.
class WorkoutDao {
  final Database _database;

  WorkoutDao(this._database);

  static const String _table = 'workouts';

  /// Retrieves all cached workouts.
  Future<List<Workout>> getAll() async {
    final rows = await _database.query(_table);
    return rows.map(_fromRow).toList();
  }

  /// Retrieves a single workout by its ID.
  ///
  /// Returns `null` if no workout with the given [id] exists.
  Future<Workout?> getById(String id) async {
    final rows = await _database.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Inserts or updates a list of workouts in a single batch.
  Future<void> upsertAll(List<Workout> workouts) async {
    final batch = _database.batch();
    for (final workout in workouts) {
      batch.insert(
        _table,
        _toRow(workout),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Inserts or updates a single workout.
  Future<void> upsert(Workout workout) async {
    await _database.insert(
      _table,
      _toRow(workout),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a workout by its ID.
  Future<void> deleteById(String id) async {
    await _database.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Converts a database row to a [Workout] model.
  Workout _fromRow(Map<String, dynamic> row) {
    // Exercises are stored as a JSON-encoded string in SQLite
    final exercisesJson = row['exercises'] as String;
    final exercisesList = (jsonDecode(exercisesJson) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return Workout.fromJson({
      'id': row['id'],
      'user_id': row['user_id'],
      'name': row['name'],
      'day_of_week': row['day_of_week'],
      'estimated_duration_minutes': row['estimated_duration_minutes'],
      'exercises': exercisesList,
      'is_generated': row['is_generated'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    });
  }

  /// Converts a [Workout] model to a database row map.
  Map<String, dynamic> _toRow(Workout workout) {
    return {
      'id': workout.id,
      'user_id': workout.userId,
      'name': workout.name,
      'day_of_week': workout.dayOfWeek,
      'estimated_duration_minutes': workout.estimatedDurationMinutes,
      'exercises': jsonEncode(
        workout.exercises.map((e) => e.toJson()).toList(),
      ),
      'is_generated': workout.isGenerated ? 1 : 0,
      'created_at': workout.createdAt?.toIso8601String(),
      'updated_at': workout.updatedAt?.toIso8601String(),
    };
  }
}
