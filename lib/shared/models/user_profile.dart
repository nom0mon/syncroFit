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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'].toString(),
      name: json['name'] as String,
      age: json['age'] as int,
      heightCm: (json['height_cm'] as num).toDouble(),
      weightKg: (json['weight_kg'] as num).toDouble(),
      gender: _genderFromJson(json['gender'] as String),
      fitnessGoal: _fitnessGoalFromJson(json['fitness_goal'] as String),
      fitnessLevel: _fitnessLevelFromJson(json['fitness_level'] as String),
      workoutPreference:
          _workoutPreferenceFromJson(json['workout_preference'] as String),
      workoutAvailability: (json['availability_days'] as List<dynamic>)
          .map((e) => _dayOfWeekFromJson(e as String))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'gender': gender.name,
        'fitness_goal': _fitnessGoalToJson(fitnessGoal),
        'fitness_level': fitnessLevel.name,
        'workout_preference': workoutPreference.name,
        'availability_days': workoutAvailability.map((d) => d.name).toList(),
      };

  static Gender _genderFromJson(String value) {
    switch (value) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      default:
        return Gender.other;
    }
  }

  static FitnessGoal _fitnessGoalFromJson(String value) {
    switch (value) {
      case 'lose_weight':
        return FitnessGoal.loseWeight;
      case 'build_muscle':
        return FitnessGoal.buildMuscle;
      case 'stay_fit':
        return FitnessGoal.maintainFitness;
      case 'increase_stamina':
        return FitnessGoal.improveEndurance;
      default:
        return FitnessGoal.maintainFitness;
    }
  }

  static String _fitnessGoalToJson(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return 'lose_weight';
      case FitnessGoal.buildMuscle:
        return 'build_muscle';
      case FitnessGoal.maintainFitness:
        return 'stay_fit';
      case FitnessGoal.improveEndurance:
        return 'increase_stamina';
    }
  }

  static FitnessLevel _fitnessLevelFromJson(String value) {
    switch (value) {
      case 'beginner':
        return FitnessLevel.beginner;
      case 'intermediate':
        return FitnessLevel.intermediate;
      case 'advanced':
        return FitnessLevel.advanced;
      default:
        return FitnessLevel.beginner;
    }
  }

  static WorkoutPreference _workoutPreferenceFromJson(String value) {
    switch (value) {
      case 'home':
        return WorkoutPreference.home;
      case 'gym':
        return WorkoutPreference.gym;
      case 'outdoor':
        return WorkoutPreference.outdoor;
      default:
        return WorkoutPreference.home;
    }
  }

  static DayOfWeek _dayOfWeekFromJson(String value) {
    switch (value) {
      case 'monday':
        return DayOfWeek.monday;
      case 'tuesday':
        return DayOfWeek.tuesday;
      case 'wednesday':
        return DayOfWeek.wednesday;
      case 'thursday':
        return DayOfWeek.thursday;
      case 'friday':
        return DayOfWeek.friday;
      case 'saturday':
        return DayOfWeek.saturday;
      case 'sunday':
        return DayOfWeek.sunday;
      default:
        return DayOfWeek.monday;
    }
  }
}
