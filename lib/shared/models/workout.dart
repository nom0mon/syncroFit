import 'workout_exercise.dart';

class Workout {
  final String id;
  final String? userId;
  final String? planId;
  final String name;
  final String? dayOfWeek;
  final int estimatedDurationMinutes;
  final List<WorkoutExercise> exercises;
  final bool isGenerated;
  final bool isAccepted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The original coach-validated exercises captured before the user
  /// customizes the workout, or `null` if the workout has never been
  /// customized. Used to detect deviation ([isCustomized]) and to restore
  /// the recommended plan.
  final List<WorkoutExercise>? baselineExercises;

  const Workout({
    required this.id,
    this.userId,
    this.planId,
    required this.name,
    this.dayOfWeek,
    required this.estimatedDurationMinutes,
    required this.exercises,
    this.isGenerated = false,
    this.isAccepted = true,
    this.createdAt,
    this.updatedAt,
    this.baselineExercises,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'].toString(),
      userId: json['user_id']?.toString(),
      planId: json['plan_id']?.toString(),
      name: json['name'] as String,
      dayOfWeek: json['day_of_week'] as String?,
      // Manually-created legacy workouts may omit this optional backend value.
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int? ?? 0,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      isGenerated: json['is_generated'] == true ||
          json['is_generated'] == 1 ||
          json['is_generated'] == '1',
      isAccepted: json['is_accepted'] == null ||
          json['is_accepted'] == true ||
          json['is_accepted'] == 1 ||
          json['is_accepted'] == '1',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      baselineExercises: json['baseline_exercises'] != null
          ? (json['baseline_exercises'] as List<dynamic>)
              .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'plan_id': planId,
        'name': name,
        'day_of_week': dayOfWeek,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'is_generated': isGenerated,
        'is_accepted': isAccepted,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        if (baselineExercises != null)
          'baseline_exercises': baselineExercises!.map((e) => e.toJson()).toList(),
      };

  /// Returns a copy of this workout with the given fields replaced.
  Workout copyWith({
    String? id,
    String? userId,
    String? planId,
    String? name,
    String? dayOfWeek,
    int? estimatedDurationMinutes,
    List<WorkoutExercise>? exercises,
    bool? isGenerated,
    bool? isAccepted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WorkoutExercise>? baselineExercises,
  }) {
    return Workout(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      exercises: exercises ?? this.exercises,
      isGenerated: isGenerated ?? this.isGenerated,
      isAccepted: isAccepted ?? this.isAccepted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      baselineExercises: baselineExercises ?? this.baselineExercises,
    );
  }

  /// Whether the current exercises deviate from the coach's original
  /// recommendation (the [baselineExercises]).
  bool get isCustomized {
    final baseline = baselineExercises;
    if (baseline == null) return false;
    return !_listEquals(exercises, baseline);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workout &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          planId == other.planId &&
          name == other.name &&
          dayOfWeek == other.dayOfWeek &&
          estimatedDurationMinutes == other.estimatedDurationMinutes &&
          _listEquals(exercises, other.exercises) &&
          isGenerated == other.isGenerated &&
          isAccepted == other.isAccepted &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          ((baselineExercises == null &&
                  other.baselineExercises == null) ||
              (baselineExercises != null &&
                  other.baselineExercises != null &&
                  _listEquals(baselineExercises!, other.baselineExercises!)));

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        planId,
        name,
        dayOfWeek,
        estimatedDurationMinutes,
        Object.hashAll(exercises),
        isGenerated,
        isAccepted,
        createdAt,
        updatedAt,
        Object.hashAll(baselineExercises ?? const []),
      );

  static bool _listEquals(List<WorkoutExercise> a, List<WorkoutExercise> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'Workout(id: $id, userId: $userId, name: $name, dayOfWeek: $dayOfWeek, '
      'estimatedDurationMinutes: $estimatedDurationMinutes, '
      'exercises: $exercises, isGenerated: $isGenerated, '
      'createdAt: $createdAt, updatedAt: $updatedAt)';
}
