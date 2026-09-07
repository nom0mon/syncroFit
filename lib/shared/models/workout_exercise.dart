class WorkoutExercise {
  final int exerciseId;
  final int sets;
  final int reps;
  final int durationSeconds;
  final int restSeconds;
  final int order;

  const WorkoutExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.durationSeconds,
    this.restSeconds = 120,
    required this.order,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      exerciseId: json['exercise_id'] as int,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      durationSeconds: (json['duration_seconds'] ?? 0) as int,
      restSeconds: (json['rest_seconds'] ?? 120) as int,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'sets': sets,
        'reps': reps,
        'duration_seconds': durationSeconds,
        'rest_seconds': restSeconds,
        'order': order,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutExercise &&
          runtimeType == other.runtimeType &&
          exerciseId == other.exerciseId &&
          sets == other.sets &&
          reps == other.reps &&
          durationSeconds == other.durationSeconds &&
          restSeconds == other.restSeconds &&
          order == other.order;

  @override
  int get hashCode =>
      Object.hash(exerciseId, sets, reps, durationSeconds, restSeconds, order);

  @override
  String toString() =>
      'WorkoutExercise(exerciseId: $exerciseId, sets: $sets, reps: $reps, durationSeconds: $durationSeconds, restSeconds: $restSeconds, order: $order)';
}
