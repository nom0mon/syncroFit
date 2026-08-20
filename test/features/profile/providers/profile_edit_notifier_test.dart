import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/features/profile/providers/profile_edit_notifier.dart';
import 'package:synchrofit/shared/models/models.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository mockRepository;
  late UserProfile originalProfile;
  late ProfileEditNotifier notifier;

  setUp(() {
    mockRepository = MockProfileRepository();
    originalProfile = const UserProfile(
      userId: 'user-123',
      firstName: 'John',
      lastName: 'Doe',
      age: 25,
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
    notifier = ProfileEditNotifier(
      profileRepository: mockRepository,
      originalProfile: originalProfile,
    );
  });

  setUpAll(() {
    registerFallbackValue(UserProfile(
      userId: 'fallback',
      firstName: 'Fallback',
      lastName: '',
      age: 20,
      heightCm: 170.0,
      weightKg: 65.0,
      gender: Gender.male,
      fitnessGoal: FitnessGoal.buildMuscle,
      fitnessLevel: FitnessLevel.beginner,
      workoutPreference: WorkoutPreference.home,
      workoutAvailability: [DayOfWeek.monday],
    ));
  });

  group('ProfileEditNotifier - initial state', () {
    test('starts with empty dirty fields and no errors', () {
      expect(notifier.state.dirtyFields, isEmpty);
      expect(notifier.state.fieldErrors, isEmpty);
      expect(notifier.state.isSaving, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.isDirty, isFalse);
      expect(notifier.state.hasErrors, isFalse);
    });

    test('exposes the original profile', () {
      expect(notifier.originalProfile, equals(originalProfile));
    });
  });

  group('ProfileEditNotifier - updateField', () {
    test('marks a field as dirty when value differs from original', () {
      notifier.updateField('first_name', 'Jane');

      expect(notifier.state.dirtyFields, {'first_name': 'Jane'});
      expect(notifier.state.isDirty, isTrue);
    });

    test('removes field from dirty when value reverts to original', () {
      notifier.updateField('first_name', 'Jane');
      expect(notifier.state.isDirty, isTrue);

      notifier.updateField('first_name', 'John');
      expect(notifier.state.dirtyFields.containsKey('first_name'), isFalse);
      expect(notifier.state.isDirty, isFalse);
    });

    test('tracks multiple dirty fields independently', () {
      notifier.updateField('first_name', 'Jane');
      notifier.updateField('age', 30);

      expect(notifier.state.dirtyFields, {'first_name': 'Jane', 'age': 30});
    });

    test('clears field error when the field is updated', () {
      // First trigger validation to create an error
      notifier.updateField('first_name', '');
      notifier.validate();
      expect(notifier.state.fieldErrors['first_name'], isNotNull);

      // Now update the field - error should be cleared
      notifier.updateField('first_name', 'Valid Name');
      expect(notifier.state.fieldErrors.containsKey('first_name'), isFalse);
    });

    test('handles list field (availability_days) comparison correctly', () {
      notifier.updateField(
          'availability_days', [DayOfWeek.monday, DayOfWeek.tuesday]);
      expect(notifier.state.isDirty, isTrue);

      // Revert to original
      notifier.updateField('availability_days',
          [DayOfWeek.monday, DayOfWeek.wednesday, DayOfWeek.friday]);
      expect(notifier.state.isDirty, isFalse);
    });
  });

  group('ProfileEditNotifier - validate', () {
    test('returns true when all dirty fields are valid', () {
      notifier.updateField('first_name', 'Valid');
      notifier.updateField('age', 25);
      notifier.updateField('height_cm', 180.0);
      notifier.updateField('weight_kg', 75.0);

      expect(notifier.validate(), isTrue);
      expect(notifier.state.hasErrors, isFalse);
    });

    test('rejects empty first_name', () {
      notifier.updateField('first_name', '');

      expect(notifier.validate(), isFalse);
      expect(
          notifier.state.fieldErrors['first_name'], 'First name is required');
    });

    test('rejects age below 13', () {
      notifier.updateField('age', 12);

      expect(notifier.validate(), isFalse);
      expect(
          notifier.state.fieldErrors['age'], 'Age must be between 13 and 120');
    });

    test('rejects age above 120', () {
      notifier.updateField('age', 121);

      expect(notifier.validate(), isFalse);
      expect(
          notifier.state.fieldErrors['age'], 'Age must be between 13 and 120');
    });

    test('accepts age at boundary 13', () {
      notifier.updateField('age', 13);

      expect(notifier.validate(), isTrue);
    });

    test('accepts age at boundary 120', () {
      notifier.updateField('age', 120);

      expect(notifier.validate(), isTrue);
    });

    test('rejects height below 50', () {
      notifier.updateField('height_cm', 49.9);

      expect(notifier.validate(), isFalse);
      expect(notifier.state.fieldErrors['height_cm'],
          'Height must be between 50 and 300 cm');
    });

    test('rejects height above 300', () {
      notifier.updateField('height_cm', 300.1);

      expect(notifier.validate(), isFalse);
      expect(notifier.state.fieldErrors['height_cm'],
          'Height must be between 50 and 300 cm');
    });

    test('accepts height at boundary 50', () {
      notifier.updateField('height_cm', 50.0);

      expect(notifier.validate(), isTrue);
    });

    test('accepts height at boundary 300', () {
      notifier.updateField('height_cm', 300.0);

      expect(notifier.validate(), isTrue);
    });

    test('rejects weight below 20', () {
      notifier.updateField('weight_kg', 19.9);

      expect(notifier.validate(), isFalse);
      expect(notifier.state.fieldErrors['weight_kg'],
          'Weight must be between 20 and 500 kg');
    });

    test('rejects weight above 500', () {
      notifier.updateField('weight_kg', 500.1);

      expect(notifier.validate(), isFalse);
      expect(notifier.state.fieldErrors['weight_kg'],
          'Weight must be between 20 and 500 kg');
    });

    test('accepts weight at boundary 20', () {
      notifier.updateField('weight_kg', 20.0);

      expect(notifier.validate(), isTrue);
    });

    test('accepts weight at boundary 500', () {
      notifier.updateField('weight_kg', 500.0);

      expect(notifier.validate(), isTrue);
    });

    test('does not validate fields without validation rules (enums)', () {
      notifier.updateField('gender', Gender.female);
      notifier.updateField('fitness_goal', FitnessGoal.loseWeight);

      expect(notifier.validate(), isTrue);
    });

    test('reports multiple field errors at once', () {
      notifier.updateField('name', '');
      notifier.updateField('age', 5);
      notifier.updateField('height_cm', 10.0);
      notifier.updateField('weight_kg', 5.0);

      expect(notifier.validate(), isFalse);
      expect(notifier.state.fieldErrors['name'], isNotNull);
      expect(notifier.state.fieldErrors['age'], isNotNull);
      expect(notifier.state.fieldErrors['height_cm'], isNotNull);
      expect(notifier.state.fieldErrors['weight_kg'], isNotNull);
    });
  });

  group('ProfileEditNotifier - save', () {
    test('succeeds immediately if no dirty fields', () async {
      await notifier.save();

      expect(notifier.state.isSuccess, isTrue);
      expect(notifier.state.isSaving, isFalse);
      verifyNever(() => mockRepository.updateProfile(any()));
    });

    test('aborts save if validation fails', () async {
      notifier.updateField('age', 5); // invalid

      await notifier.save();

      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.isSaving, isFalse);
      expect(notifier.state.hasErrors, isTrue);
      verifyNever(() => mockRepository.updateProfile(any()));
    });

    test('calls updateProfile with merged profile on valid save', () async {
      when(() => mockRepository.updateProfile(any()))
          .thenAnswer((_) async => Success(originalProfile));

      notifier.updateField('first_name', 'New Name');
      await notifier.save();

      final captured =
          verify(() => mockRepository.updateProfile(captureAny())).captured;
      final updatedProfile = captured.first as UserProfile;

      expect(updatedProfile.firstName, 'New Name');
      expect(updatedProfile.age, 25); // unchanged
      expect(updatedProfile.heightCm, 175.0); // unchanged
      expect(updatedProfile.userId, 'user-123'); // preserved
    });

    test('sets isSuccess on successful save', () async {
      when(() => mockRepository.updateProfile(any()))
          .thenAnswer((_) async => Success(originalProfile));

      notifier.updateField('first_name', 'New Name');
      await notifier.save();

      expect(notifier.state.isSuccess, isTrue);
      expect(notifier.state.isSaving, isFalse);
      expect(notifier.state.saveError, isNull);
    });

    test('sets saveError on failed save', () async {
      when(() => mockRepository.updateProfile(any()))
          .thenAnswer((_) async => Failure(NetworkError()));

      notifier.updateField('first_name', 'New Name');
      await notifier.save();

      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.isSaving, isFalse);
      expect(notifier.state.saveError, isNotNull);
    });

    test('sends only dirty fields in the updated profile', () async {
      when(() => mockRepository.updateProfile(any()))
          .thenAnswer((_) async => Success(originalProfile));

      notifier.updateField('weight_kg', 80.0);
      await notifier.save();

      final captured =
          verify(() => mockRepository.updateProfile(captureAny())).captured;
      final updatedProfile = captured.first as UserProfile;

      // Only weight changed
      expect(updatedProfile.weightKg, 80.0);
      // Everything else remains original
      expect(updatedProfile.name, 'John Doe');
      expect(updatedProfile.age, 25);
      expect(updatedProfile.heightCm, 175.0);
      expect(updatedProfile.gender, Gender.male);
    });
  });

  group('ProfileEditNotifier - reset', () {
    test('clears all state back to initial', () {
      notifier.updateField('first_name', 'Changed');
      notifier.validate();

      notifier.reset();

      expect(notifier.state.dirtyFields, isEmpty);
      expect(notifier.state.fieldErrors, isEmpty);
      expect(notifier.state.isSaving, isFalse);
      expect(notifier.state.isSuccess, isFalse);
      expect(notifier.state.saveError, isNull);
    });
  });

  group('ProfileEditState', () {
    test('hasErrors is true when fieldErrors contains non-null values', () {
      const state = ProfileEditState(fieldErrors: {'name': 'Required'});
      expect(state.hasErrors, isTrue);
    });

    test('hasErrors is false when fieldErrors is empty', () {
      const state = ProfileEditState(fieldErrors: {});
      expect(state.hasErrors, isFalse);
    });

    test('hasErrors is false when all field errors are null', () {
      const state = ProfileEditState(fieldErrors: {'name': null});
      expect(state.hasErrors, isFalse);
    });

    test('isDirty is true when dirtyFields is non-empty', () {
      const state = ProfileEditState(dirtyFields: {'name': 'test'});
      expect(state.isDirty, isTrue);
    });

    test('isDirty is false when dirtyFields is empty', () {
      const state = ProfileEditState();
      expect(state.isDirty, isFalse);
    });

    test('copyWith creates new instance with updated fields', () {
      const original = ProfileEditState();
      final copy = original.copyWith(isSaving: true, isSuccess: false);

      expect(copy.isSaving, isTrue);
      expect(copy.isSuccess, isFalse);
      expect(copy.dirtyFields, isEmpty); // unchanged
    });

    test('copyWith clearSaveError removes saveError', () {
      const state = ProfileEditState(saveError: 'Some error');
      final cleared = state.copyWith(clearSaveError: true);

      expect(cleared.saveError, isNull);
    });
  });
}
