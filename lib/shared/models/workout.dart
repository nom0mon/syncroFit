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
}
