class WorkoutExercise {
  final int exerciseId;
  final int sets;
  final int reps;
  final int durationSeconds;
  final int order;

  const WorkoutExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.durationSeconds,
    required this.order,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      exerciseId: json['exercise_id'] as int,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      // `rest_seconds` was emitted by an earlier version of the plan
      // generator.  Accept it for already-generated plans, while new API
      // responses use the canonical `duration_seconds` field.
      durationSeconds:
          (json['duration_seconds'] ?? json['rest_seconds'] ?? 0) as int,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'sets': sets,
        'reps': reps,
        'duration_seconds': durationSeconds,
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
          order == other.order;

  @override
  int get hashCode => Object.hash(exerciseId, sets, reps, durationSeconds, order);

  @override
  String toString() =>
      'WorkoutExercise(exerciseId: $exerciseId, sets: $sets, reps: $reps, durationSeconds: $durationSeconds, order: $order)';
}
