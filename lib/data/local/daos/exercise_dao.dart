import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../shared/models/exercise.dart';

/// Data Access Object for exercises in the local SQLite database.
///
/// Handles CRUD operations for cached exercise data, including JSON encoding
/// of complex fields like instructions.
class ExerciseDao {
  final Database _database;

  ExerciseDao(this._database);

  static const String _table = 'exercises';

  /// Retrieves all cached exercises.
  Future<List<Exercise>> getAll() async {
    final rows = await _database.query(_table);
    return rows.map(_fromRow).toList();
  }

  /// Retrieves a single exercise by its ID.
  ///
  /// Returns `null` if no exercise with the given [id] exists.
  Future<Exercise?> getById(String id) async {
    final rows = await _database.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Inserts or updates a list of exercises in a single batch.
  Future<void> upsertAll(List<Exercise> exercises) async {
    final batch = _database.batch();
    for (final exercise in exercises) {
      batch.insert(
        _table,
        _toRow(exercise),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Inserts or updates a single exercise.
  Future<void> upsert(Exercise exercise) async {
    await _database.insert(
      _table,
      _toRow(exercise),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes an exercise by its ID.
  Future<void> deleteById(String id) async {
    await _database.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Converts a database row to an [Exercise] model.
  Exercise _fromRow(Map<String, dynamic> row) {
    // Instructions are stored as a JSON-encoded string in SQLite
    final instructionsJson = row['instructions'] as String;
    final instructions = (jsonDecode(instructionsJson) as List<dynamic>)
        .map((e) => e as String)
        .toList();

    return Exercise.fromJson({
      'id': row['id'],
      'name': row['name'],
      'muscle_group': row['muscle_group'],
      'difficulty': row['difficulty'],
      'instructions': instructions,
      'equipment': row['equipment'],
      'default_duration_seconds': row['default_duration_seconds'],
      'default_sets': row['default_sets'],
      'default_reps': row['default_reps'],
      'video_path': row['video_path'],
    });
  }

  /// Converts an [Exercise] model to a database row map.
  Map<String, dynamic> _toRow(Exercise exercise) {
    return {
      'id': exercise.id,
      'name': exercise.name,
      'muscle_group': exercise.muscleGroup,
      'difficulty': exercise.difficulty.name,
      'instructions': jsonEncode(exercise.instructions),
      'equipment': exercise.equipment,
      'default_duration_seconds': exercise.defaultDurationSeconds,
      'default_sets': exercise.defaultSets,
      'default_reps': exercise.defaultReps,
      'video_path': exercise.videoPath,
    };
  }
}
