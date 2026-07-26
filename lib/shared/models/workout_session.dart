import 'completed_exercise.dart';

class WorkoutSession {
  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime completedAt;
  final int totalDurationSeconds;
  final int exercisesCompleted;
  final List<CompletedExercise> exercises;

  const WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.completedAt,
    required this.totalDurationSeconds,
    required this.exercisesCompleted,
    required this.exercises,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'].toString(),
      workoutId: json['workout_id'].toString(),
      workoutName: json['workout_name'] as String,
      completedAt: DateTime.parse(json['completed_at'] as String),
      totalDurationSeconds: json['total_duration_seconds'] as int,
      exercisesCompleted: json['exercises_completed'] as int,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => CompletedExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workout_id': workoutId,
        'workout_name': workoutName,
        'completed_at': completedAt.toIso8601String(),
        'total_duration_seconds': totalDurationSeconds,
        'exercises_completed': exercisesCompleted,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}
