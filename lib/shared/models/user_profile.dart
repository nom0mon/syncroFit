import 'enums.dart';

class UserProfile {
  final String userId;
  final String name;
  final int age;
  final double heightCm;
  final double weightKg;
  final Gender gender;
  final FitnessGoal fitnessGoal;
  final FitnessLevel fitnessLevel;
  final WorkoutPreference workoutPreference;
  final List<DayOfWeek> workoutAvailability;

  const UserProfile({
    required this.userId,
    required this.name,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.gender,
    required this.fitnessGoal,
    required this.fitnessLevel,
    required this.workoutPreference,
    required this.workoutAvailability,
  });
}
