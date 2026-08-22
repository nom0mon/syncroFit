class CompletedExercise {
  final String exerciseId;
  final String exerciseName;
  final int setsCompleted;

  /// The value of [repsOrDuration]: reps count for rep-based exercises, or
  /// seconds for timed exercises (see [isDuration]).
  final int repsOrDuration;

  /// Whether [repsOrDuration] represents a duration in seconds (true) rather
  /// than a repetition count (false). Used so training-volume metrics can
  /// exclude timed exercises from rep-based totals.
  final bool isDuration;

  const CompletedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.setsCompleted,
    required this.repsOrDuration,
    this.isDuration = false,
  });

  /// The number of reps completed across all sets, or 0 for timed exercises.
  ///
  /// This is the value used for training-volume (weekly load) calculations,
  /// which count reps only and ignore timed exercises.
  int get repVolume => isDuration ? 0 : setsCompleted * repsOrDuration;

  factory CompletedExercise.fromJson(Map<String, dynamic> json) {
    return CompletedExercise(
      exerciseId: json['exercise_id'].toString(),
      exerciseName: json['exercise_name'] as String,
      setsCompleted: json['sets_completed'] as int,
      repsOrDuration: json['reps_or_duration'] as int,
      isDuration: json['is_duration'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'sets_completed': setsCompleted,
        'reps_or_duration': repsOrDuration,
        'is_duration': isDuration,
      };
}
