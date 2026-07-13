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
}
