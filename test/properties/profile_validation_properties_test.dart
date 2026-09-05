import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:mocktail/mocktail.dart' hide any;
import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/features/profile/providers/profile_edit_notifier.dart';
import 'package:synchrofit/shared/models/models.dart';

// Feature: offline-support-and-ui-enhancements, Property 6: Profile validation rejects out-of-range values
// Feature: offline-support-and-ui-enhancements, Property 7: Profile PATCH sends only changed fields

class MockProfileRepository extends Mock implements ProfileRepository {}

/// A valid base profile used for testing.
UserProfile _createOriginalProfile() {
  return const UserProfile(
    userId: 'test-user-1',
    firstName: 'John',
    lastName: 'Doe',
    age: 30,
    heightCm: 175.0,
    weightKg: 70.0,
    gender: Gender.male,
    fitnessGoal: FitnessGoal.buildMuscle,
    fitnessLevel: FitnessLevel.intermediate,
    workoutPreference: WorkoutPreference.gym,
    workoutAvailability: [
      DayOfWeek.monday,
      DayOfWeek.wednesday,
      DayOfWeek.friday
    ],
  );
}

void main() {
  late MockProfileRepository mockRepo;

  setUp(() {
    mockRepo = MockProfileRepository();
  });

  // =====================================================================
  // Property 6: Profile validation rejects out-of-range values
  // =====================================================================
  group('Property 6: Profile validation rejects out-of-range values', () {
    /// **Validates: Requirements 6.1, 6.5**
    ///
    /// For any age outside [13, 120], validate() returns false and
    /// fieldErrors['age'] contains the expected error message.
    Glados(any.intInRange(-1000, 13)).test(
      'age below 13 fails validation',
      (age) {
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: _createOriginalProfile(),
        );

        notifier.updateField('age', age);
        final isValid = notifier.validate();

        expect(isValid, isFalse);
        expect(
          notifier.state.fieldErrors['age'],
          equals('Age must be between 13 and 120'),
        );
      },
    );

    /// **Validates: Requirements 6.1, 6.5**
    Glados(any.intInRange(121, 1000)).test(
      'age above 120 fails validation',
      (age) {
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: _createOriginalProfile(),
        );

        notifier.updateField('age', age);
        final isValid = notifier.validate();

        expect(isValid, isFalse);
        expect(
          notifier.state.fieldErrors['age'],
          equals('Age must be between 13 and 120'),
        );
      },
    );

    /// **Validates: Requirements 6.1, 6.5**
    Glados(any.doubleInRange(-100.0, 49.9)).test(
      'height below 50 cm fails validation',
      (height) {
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: _createOriginalProfile(),
        );

        notifier.updateField('height_cm', height);
        final isValid = notifier.validate();

        expect(isValid, isFalse);
        expect(
          notifier.state.fieldErrors['height_cm'],
          equals('Height must be between 50 and 300 cm'),
        );
      },
    );

    /// **Validates: Requirements 6.1, 6.5**
    Glados(any.doubleInRange(300.1, 1000.0)).test(
      'height above 300 cm fails validation',
      (height) {
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: _createOriginalProfile(),
        );

        notifier.updateField('height_cm', height);
        final isValid = notifier.validate();

        expect(isValid, isFalse);
        expect(
          notifier.state.fieldErrors['height_cm'],
          equals('Height must be between 50 and 300 cm'),
        );
      },
    );

    /// **Validates: Requirements 6.1, 6.5**
    Glados(any.doubleInRange(-100.0, 19.9)).test(
      'weight below 20 kg fails validation',
      (weight) {
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: _createOriginalProfile(),
        );

        notifier.updateField('weight_kg', weight);
        final isValid = notifier.validate();

        expect(isValid, isFalse);
        expect(
          notifier.state.fieldErrors['weight_kg'],
          equals('Weight must be between 20 and 500 kg'),
        );
      },
    );

    /// **Validates: Requirements 6.1, 6.5**
    Glados(any.doubleInRange(500.1, 2000.0)).test(
      'weight above 500 kg fails validation',
      (weight) {
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: _createOriginalProfile(),
        );

        notifier.updateField('weight_kg', weight);
        final isValid = notifier.validate();

        expect(isValid, isFalse);
        expect(
          notifier.state.fieldErrors['weight_kg'],
          equals('Weight must be between 20 and 500 kg'),
        );
      },
    );

    /// **Validates: Requirements 6.1, 6.5**
    ///
    /// In-range values pass validation.
    Glados3(
      any.intInRange(13, 121),
      any.doubleInRange(50.0, 300.0),
      any.doubleInRange(20.0, 500.0),
    ).test(
      'in-range age, height, and weight pass validation',
      (age, height, weight) {
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: _createOriginalProfile(),
        );

        notifier.updateField('age', age);
        notifier.updateField('height_cm', height);
        notifier.updateField('weight_kg', weight);
        final isValid = notifier.validate();

        expect(isValid, isTrue);
        expect(notifier.state.fieldErrors, isEmpty);
      },
    );
  });

  // =====================================================================
  // Property 7: Profile PATCH sends only changed fields
  // =====================================================================
  group('Property 7: Profile PATCH sends only changed fields', () {
    /// **Validates: Requirements 6.2, 6.4**
    ///
    /// For any subset of fields modified with different values,
    /// dirtyFields.keys contains exactly those fields.
    Glados(any.intInRange(1, 9)).test(
      'dirtyFields contains exactly the modified field subset',
      (fieldCount) {
        final original = _createOriginalProfile();
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: original,
        );

        // All available fields with values different from the original
        final fieldUpdates = <String, dynamic>{
          'name': 'Jane Smith',
          'age': 25,
          'height_cm': 160.0,
          'weight_kg': 55.0,
          'gender': Gender.female,
          'fitness_goal': FitnessGoal.loseWeight,
          'fitness_level': FitnessLevel.beginner,
          'workout_preference': WorkoutPreference.home,
          'availability_days': [DayOfWeek.tuesday, DayOfWeek.thursday],
        };

        final allFields = fieldUpdates.keys.toList();
        // Pick the first N fields (deterministic subset based on fieldCount)
        final selectedFields = allFields.take(fieldCount).toList();

        for (final field in selectedFields) {
          notifier.updateField(field, fieldUpdates[field]);
        }

        // Assert dirtyFields contains exactly the selected fields
        expect(
          notifier.state.dirtyFields.keys.toSet(),
          equals(selectedFields.toSet()),
        );
      },
    );

    /// **Validates: Requirements 6.2, 6.4**
    ///
    /// Reverting a field to its original value removes it from dirtyFields.
    Glados(any.intInRange(1, 9)).test(
      'reverting a field to original removes it from dirtyFields',
      (fieldCount) {
        final original = _createOriginalProfile();
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: original,
        );

        final fieldUpdates = <String, dynamic>{
          'first_name': 'Jane',
          'age': 25,
          'height_cm': 160.0,
          'weight_kg': 55.0,
          'gender': Gender.female,
          'fitness_goal': FitnessGoal.loseWeight,
          'fitness_level': FitnessLevel.beginner,
          'workout_preference': WorkoutPreference.home,
          'availability_days': [DayOfWeek.tuesday, DayOfWeek.thursday],
        };

        final originalValues = <String, dynamic>{
          'first_name': original.firstName,
          'age': original.age,
          'height_cm': original.heightCm,
          'weight_kg': original.weightKg,
          'gender': original.gender,
          'fitness_goal': original.fitnessGoal,
          'fitness_level': original.fitnessLevel,
          'workout_preference': original.workoutPreference,
          'availability_days': original.workoutAvailability,
        };

        final allFields = fieldUpdates.keys.toList();
        final selectedFields = allFields.take(fieldCount).toList();

        // First, modify all selected fields
        for (final field in selectedFields) {
          notifier.updateField(field, fieldUpdates[field]);
        }

        // Verify they're all dirty
        expect(
          notifier.state.dirtyFields.keys.toSet(),
          equals(selectedFields.toSet()),
        );

        // Now revert each field back to original
        for (final field in selectedFields) {
          notifier.updateField(field, originalValues[field]);
        }

        // All fields should be removed from dirtyFields
        expect(notifier.state.dirtyFields, isEmpty);
      },
    );

    /// **Validates: Requirements 6.2, 6.4**
    ///
    /// Partially reverting fields leaves only the non-reverted ones dirty.
    Glados(any.intInRange(2, 9)).test(
      'partially reverting fields leaves only non-reverted ones dirty',
      (fieldCount) {
        final original = _createOriginalProfile();
        final notifier = ProfileEditNotifier(
          profileRepository: mockRepo,
          originalProfile: original,
        );

        final fieldUpdates = <String, dynamic>{
          'first_name': 'Jane',
          'age': 25,
          'height_cm': 160.0,
          'weight_kg': 55.0,
          'gender': Gender.female,
          'fitness_goal': FitnessGoal.loseWeight,
          'fitness_level': FitnessLevel.beginner,
          'workout_preference': WorkoutPreference.home,
          'availability_days': [DayOfWeek.tuesday, DayOfWeek.thursday],
        };

        final originalValues = <String, dynamic>{
          'first_name': original.firstName,
          'age': original.age,
          'height_cm': original.heightCm,
          'weight_kg': original.weightKg,
          'gender': original.gender,
          'fitness_goal': original.fitnessGoal,
          'fitness_level': original.fitnessLevel,
          'workout_preference': original.workoutPreference,
          'availability_days': original.workoutAvailability,
        };

        final allFields = fieldUpdates.keys.toList();
        final selectedFields = allFields.take(fieldCount).toList();

        // Modify all selected fields
        for (final field in selectedFields) {
          notifier.updateField(field, fieldUpdates[field]);
        }

        // Revert the first field only
        final revertedField = selectedFields.first;
        notifier.updateField(revertedField, originalValues[revertedField]);

        // dirtyFields should contain all selected except the reverted one
        final expectedDirty = selectedFields.skip(1).toSet();
        expect(
          notifier.state.dirtyFields.keys.toSet(),
          equals(expectedDirty),
        );
      },
    );
  });
}
