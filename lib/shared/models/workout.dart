import 'workout_exercise.dart';

class Workout {
  final String id;
  final String name;
  final int estimatedDurationMinutes;
  final List<WorkoutExercise> exercises;

  const Workout({
    required this.id,
    required this.name,
    required this.estimatedDurationMinutes,
    required this.exercises,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'].toString(),
      name: json['name'] as String,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}
