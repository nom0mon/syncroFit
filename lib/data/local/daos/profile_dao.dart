import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../shared/models/user_profile.dart';

/// Data Access Object for user profile in the local SQLite database.
///
/// Profiles are keyed by user ID so switching accounts on one device does not
/// expose or hide another account's cached profile.
class ProfileDao {
  final Database _database;

  ProfileDao(this._database);

  static const String _table = 'user_profile';

  /// Retrieves the cached user profile.
  ///
  /// Returns `null` if no profile is stored locally.
  Future<UserProfile?> get({String? userId}) async {
    final rows = await _database.query(
      _table,
      where: userId == null ? null : 'user_id = ?',
      whereArgs: userId == null ? null : [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Inserts or updates the user profile.
  Future<void> upsert(UserProfile profile) async {
    await _database.insert(
      _table,
      _toRow(profile),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes the stored user profile.
  Future<void> delete() async {
    await _database.delete(_table);
  }

  /// Converts a database row to a [UserProfile] model.
  UserProfile _fromRow(Map<String, dynamic> row) {
    // availability_days is stored as a JSON-encoded string
    final availabilityJson = row['availability_days'] as String;
    final availabilityDays = (jsonDecode(availabilityJson) as List<dynamic>)
        .map((e) => e as String)
        .toList();

    return UserProfile.fromJson({
      'user_id': row['user_id'],
      'name': row['name'],
      'first_name': row['first_name'],
      'last_name': row['last_name'],
      'username': row['username'],
      'age': row['age'],
      'height_cm': row['height_cm'],
      'weight_kg': row['weight_kg'],
      'gender': row['gender'],
      'fitness_goal': row['fitness_goal'],
      'fitness_level': row['fitness_level'],
      'workout_preference': row['workout_preference'],
      'availability_days': availabilityDays,
      'updated_at': row['updated_at'],
    });
  }

  /// Converts a [UserProfile] model to a database row map.
  Map<String, dynamic> _toRow(UserProfile profile) {
    return {
      'user_id': profile.userId,
      'name': profile.name,
      'first_name': profile.firstName,
      'last_name': profile.lastName,
      'username': profile.username,
      'age': profile.age,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'gender': profile.gender.name,
      'fitness_goal': _fitnessGoalToJson(profile.fitnessGoal),
      'fitness_level': profile.fitnessLevel.name,
      'workout_preference': profile.workoutPreference.name,
      'availability_days': jsonEncode(
        profile.workoutAvailability.map((d) => d.name).toList(),
      ),
      'updated_at': profile.updatedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
    };
  }

  /// Mirrors the JSON encoding logic from [UserProfile.toJson].
  static String _fitnessGoalToJson(dynamic goal) {
    switch (goal.toString()) {
      case 'FitnessGoal.loseWeight':
        return 'lose_weight';
      case 'FitnessGoal.buildMuscle':
        return 'build_muscle';
      case 'FitnessGoal.maintainFitness':
        return 'stay_fit';
      case 'FitnessGoal.improveEndurance':
        return 'increase_stamina';
      default:
        return 'stay_fit';
    }
  }
}
