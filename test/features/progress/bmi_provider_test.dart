import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/profile/providers/profile_provider.dart';
import 'package:synchrofit/features/progress/providers/progress_provider.dart';
import 'package:synchrofit/features/progress/utils/bmi_utils.dart';
import 'package:synchrofit/shared/models/models.dart';

void main() {
  test('derives BMI from the current profile and updates reactively', () async {
    late _MutableProfileNotifier profileNotifier;
    final container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(() {
          profileNotifier = _MutableProfileNotifier(_profile(weightKg: 70));
          return profileNotifier;
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileProvider.future);

    expect(container.read(bmiProvider).value!.displayValue, '22.9');
    expect(
      container.read(bmiProvider).value!.category,
      BmiCategory.healthy,
    );

    profileNotifier.replace(_profile(weightKg: 80));

    expect(container.read(bmiProvider).value!.displayValue, '26.1');
    expect(
      container.read(bmiProvider).value!.category,
      BmiCategory.overweight,
    );
  });

  test('returns no BMI when the user has no profile', () async {
    final container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(() => _MutableProfileNotifier(null)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileProvider.future);

    expect(container.read(bmiProvider).value, isNull);
  });
}

UserProfile _profile({required double weightKg}) => UserProfile(
      userId: 'user-1',
      firstName: 'Test',
      lastName: 'Member',
      age: 25,
      heightCm: 175,
      weightKg: weightKg,
      gender: Gender.other,
      fitnessGoal: FitnessGoal.maintainFitness,
      fitnessLevel: FitnessLevel.intermediate,
      workoutPreference: WorkoutPreference.gym,
      workoutAvailability: const [DayOfWeek.monday],
    );

class _MutableProfileNotifier extends ProfileNotifier {
  _MutableProfileNotifier(this.initialProfile);

  final UserProfile? initialProfile;

  @override
  Future<UserProfile?> build() async => initialProfile;

  void replace(UserProfile? profile) {
    state = AsyncValue.data(profile);
  }
}
