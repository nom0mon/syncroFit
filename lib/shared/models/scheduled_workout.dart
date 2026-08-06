import 'enums.dart';

/// A scheduled workout for a specific day of the week.
class ScheduledWorkout {
  final String workoutId;
  final String workoutName;
  final DayOfWeek dayOfWeek;
  final int estimatedDurationMinutes;
  final bool isCompleted;
  final DateTime? completedAt;

  const ScheduledWorkout({
    required this.workoutId,
    required this.workoutName,
    required this.dayOfWeek,
    required this.estimatedDurationMinutes,
    this.isCompleted = false,
    this.completedAt,
  });

  ScheduledWorkout copyWith({
    String? workoutId,
    String? workoutName,
    DayOfWeek? dayOfWeek,
    int? estimatedDurationMinutes,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return ScheduledWorkout(
      workoutId: workoutId ?? this.workoutId,
      workoutName: workoutName ?? this.workoutName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
