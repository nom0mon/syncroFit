class CompletedExercise {
  final String exerciseId;
  final String exerciseName;
  final int setsCompleted;
  final int repsOrDuration;

  const CompletedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.setsCompleted,
    required this.repsOrDuration,
  });

  factory CompletedExercise.fromJson(Map<String, dynamic> json) {
    return CompletedExercise(
      exerciseId: json['exercise_id'].toString(),
      exerciseName: json['exercise_name'] as String,
      setsCompleted: json['sets_completed'] as int,
      repsOrDuration: json['reps_or_duration'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'sets_completed': setsCompleted,
        'reps_or_duration': repsOrDuration,
      };
}
