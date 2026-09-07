import 'dart:convert';

import 'package:synchrofit/shared/models/completed_exercise.dart';

class WorkoutHistory {
  final String id;
  final String userId;
  final String workoutName;
  final DateTime completedAt;
  final int totalDurationSeconds;
  final List<Map<String, dynamic>> exercisesCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkoutHistory({
    required this.id,
    required this.userId,
    required this.workoutName,
    required this.completedAt,
    required this.totalDurationSeconds,
    required this.exercisesCompleted,
    this.createdAt,
    this.updatedAt,
  });

  /// Completion time used for calendar aggregation.
  ///
  /// Older mobile builds sent a timezone-less local completion value which
  /// Laravel interpreted as UTC. Immediate online saves can be recognized by
  /// the resulting 7-9 hour difference from the server creation timestamp.
  DateTime get effectiveCompletedAt {
    final created = createdAt;
    if (created == null) return completedAt.toLocal();
    final difference = completedAt.difference(created).abs();
    if (difference >= const Duration(hours: 7) &&
        difference <= const Duration(hours: 9)) {
      return created.toLocal();
    }
    return completedAt.toLocal();
  }

  factory WorkoutHistory.fromJson(Map<String, dynamic> json) {
    return WorkoutHistory(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      workoutName: json['workout_name'] as String,
      // API timestamps are UTC; dashboard calendar/week boundaries are local.
      completedAt: DateTime.parse(json['completed_at'] as String).toLocal(),
      totalDurationSeconds: json['total_duration_seconds'] as int,
      exercisesCompleted: _parseExercisesCompleted(json['exercises_completed']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'workout_name': workoutName,
        'completed_at': completedAt.toIso8601String(),
        'total_duration_seconds': totalDurationSeconds,
        'exercises_completed': exercisesCompleted,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Parses the exercises_completed field which may come as a JSON string
  /// (from SQLite) or as a List (from API response).
  static List<Map<String, dynamic>> _parseExercisesCompleted(dynamic value) {
    if (value is String) {
      final decoded = jsonDecode(value) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (value is List) {
      return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  WorkoutHistory copyWith({
    String? id,
    String? userId,
    String? workoutName,
    DateTime? completedAt,
    int? totalDurationSeconds,
    List<Map<String, dynamic>>? exercisesCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workoutName: workoutName ?? this.workoutName,
      completedAt: completedAt ?? this.completedAt,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      exercisesCompleted: exercisesCompleted ?? this.exercisesCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WorkoutHistory) return false;
    return id == other.id &&
        userId == other.userId &&
        workoutName == other.workoutName &&
        completedAt == other.completedAt &&
        totalDurationSeconds == other.totalDurationSeconds &&
        _listEquals(exercisesCompleted, other.exercisesCompleted) &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        workoutName,
        completedAt,
        totalDurationSeconds,
        Object.hashAll(exercisesCompleted.map((e) => Object.hashAll(
              e.entries.map((entry) => Object.hash(entry.key, entry.value)),
            ))),
        createdAt,
        updatedAt,
      );

  /// Returns the number of exercises completed.
  int get exercisesCompletedCount => exercises.length;

  /// Returns a list of [CompletedExercise] objects parsed from
  /// the [exercisesCompleted] maps.
  List<CompletedExercise> get exercises {
    final unique = <String, CompletedExercise>{};
    for (final json in exercisesCompleted) {
      final exercise = CompletedExercise.fromJson(json);
      unique.putIfAbsent(exercise.exerciseId, () => exercise);
    }
    return unique.values.toList();
  }

  @override
  String toString() =>
      'WorkoutHistory(id: $id, workoutName: $workoutName, completedAt: $completedAt)';

  static bool _listEquals(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (final key in a[i].keys) {
        if (a[i][key] != b[i][key]) return false;
      }
    }
    return true;
  }
}
