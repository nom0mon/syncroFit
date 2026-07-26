class WorkoutExercise {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int reps;
  final int durationSeconds;
  final int restSeconds;
  final String thumbnailPlaceholder;

  const WorkoutExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.durationSeconds,
    required this.restSeconds,
    required this.thumbnailPlaceholder,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      exerciseId: json['exercise_id'].toString(),
      exerciseName: json['exercise_name'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      durationSeconds: json['duration_seconds'] as int,
      restSeconds: json['rest_seconds'] as int,
      thumbnailPlaceholder: (json['image_url'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'sets': sets,
        'reps': reps,
        'duration_seconds': durationSeconds,
        'rest_seconds': restSeconds,
        'image_url': thumbnailPlaceholder,
      };
}
