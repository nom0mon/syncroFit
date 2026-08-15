import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/features/profile/providers/profile_provider.dart';
import 'package:synchrofit/shared/models/enums.dart';
import 'package:synchrofit/shared/models/result.dart';
import 'package:synchrofit/shared/models/user_profile.dart';

/// State representing the multi-step assessment form.
class AssessmentState {
  /// Current step (1-3).
  final int currentStep;

  // Step 1: BMI data
  final double? heightCm;
  final double? weightKg;
  final double? bmi;

  // Step 2: Physical info
  final int? age;
  final Gender? gender;
  final ActivityLevel? activityLevel;

  // Step 3: Goals
  final FitnessGoal? fitnessGoal;
  final int? trainingExperienceYears;

  const AssessmentState({
    this.currentStep = 1,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.age,
    this.gender,
    this.activityLevel,
    this.fitnessGoal,
    this.trainingExperienceYears,
  });

  AssessmentState copyWith({
    int? currentStep,
    double? heightCm,
    double? weightKg,
    double? bmi,
    int? age,
    Gender? gender,
    ActivityLevel? activityLevel,
    FitnessGoal? fitnessGoal,
    int? trainingExperienceYears,
  }) {
    return AssessmentState(
      currentStep: currentStep ?? this.currentStep,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bmi: bmi ?? this.bmi,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      trainingExperienceYears:
          trainingExperienceYears ?? this.trainingExperienceYears,
    );
  }
}

/// StateNotifier managing the multi-step assessment form state.
class AssessmentNotifier extends StateNotifier<AssessmentState> {
  final ProfileRepository _profileRepository;

  AssessmentNotifier(this._profileRepository) : super(const AssessmentState());

  /// Updates step 1 data (height, weight) and computes BMI.
  void updateStep1(double height, double weight) {
    final computedBmi = calculateBmi(height, weight);
    state = state.copyWith(
      heightCm: height,
      weightKg: weight,
      bmi: computedBmi,
    );
  }

  /// Updates step 2 data (age, gender, activity level).
  void updateStep2(int age, Gender gender, ActivityLevel activityLevel) {
    state = state.copyWith(
      age: age,
      gender: gender,
      activityLevel: activityLevel,
    );
  }

  /// Updates step 3 data (fitness goal, training experience).
  void updateStep3(FitnessGoal goal, int experience) {
    state = state.copyWith(
      fitnessGoal: goal,
      trainingExperienceYears: experience,
    );
  }

  /// Navigates to the specified step (1-3).
  /// Step data is retained when navigating back.
  void goToStep(int step) {
    if (step >= 1 && step <= 3) {
      state = state.copyWith(currentStep: step);
    }
  }

  /// Calculates BMI from height (cm) and weight (kg).
  /// Formula: weight / (height/100)²
  /// Returns result rounded to 1 decimal place.
  double calculateBmi(double heightCm, double weightKg) {
    final heightM = heightCm / 100;
    final rawBmi = weightKg / (heightM * heightM);
    // Round to 1 decimal place
    return (rawBmi * 10).roundToDouble() / 10;
  }

  /// Saves the assessment data to the profile repository.
  Future<bool> saveAssessment() async {
    final profile = UserProfile(
      userId: 'user-1',
      firstName: '',
      lastName: 'User',
      age: state.age ?? 25,
      heightCm: state.heightCm ?? 170,
      weightKg: state.weightKg ?? 70,
      gender: state.gender ?? Gender.other,
      fitnessGoal: state.fitnessGoal ?? FitnessGoal.maintainFitness,
      fitnessLevel: FitnessLevel.beginner,
      workoutPreference: WorkoutPreference.gym,
      workoutAvailability: [
        DayOfWeek.monday,
        DayOfWeek.wednesday,
        DayOfWeek.friday
      ],
    );

    final result = await _profileRepository.saveProfile(profile);
    return switch (result) {
      Success() => true,
      Failure() => false,
    };
  }
}

/// Provider for the profile repository used by the assessment flow.
/// Re-uses the app-wide profileRepositoryProvider (remote-backed).
final assessmentProfileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ref.watch(profileRepositoryProvider);
});

/// Provider for the assessment state notifier.
final assessmentProvider =
    StateNotifierProvider<AssessmentNotifier, AssessmentState>((ref) {
  final repository = ref.watch(assessmentProfileRepositoryProvider);
  return AssessmentNotifier(repository);
});
