import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../shared/models/models.dart';
import 'profile_provider.dart';

/// State for the profile edit form.
///
/// Tracks which fields have been modified (dirty), any validation errors,
/// and the saving/success lifecycle.
class ProfileEditState {
  const ProfileEditState({
    this.dirtyFields = const {},
    this.fieldErrors = const {},
    this.isSaving = false,
    this.isSuccess = false,
    this.saveError,
  });

  /// Map of field names to their current (modified) values.
  /// Only fields the user has changed appear here.
  final Map<String, dynamic> dirtyFields;

  /// Map of field names to validation error messages.
  /// A null value or absent key means the field is valid.
  final Map<String, String?> fieldErrors;

  /// Whether a save operation is currently in progress.
  final bool isSaving;

  /// Whether the last save completed successfully.
  final bool isSuccess;

  /// An error message from the last failed save attempt, if any.
  final String? saveError;

  /// Whether there are any validation errors.
  bool get hasErrors => fieldErrors.values.any((e) => e != null);

  /// Whether the form has unsaved changes.
  bool get isDirty => dirtyFields.isNotEmpty;

  ProfileEditState copyWith({
    Map<String, dynamic>? dirtyFields,
    Map<String, String?>? fieldErrors,
    bool? isSaving,
    bool? isSuccess,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return ProfileEditState(
      dirtyFields: dirtyFields ?? this.dirtyFields,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      isSaving: isSaving ?? this.isSaving,
      isSuccess: isSuccess ?? this.isSuccess,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

/// Manages profile edit form state with client-side validation and
/// PATCH-style dirty field tracking.
///
/// Holds a reference to the original [UserProfile] and tracks which fields
/// the user has modified. On save, validates all dirty fields and delegates
/// to [ProfileRepository.updateProfile] — the caching repository handles
/// online/offline semantics transparently.
class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  ProfileEditNotifier({
    required ProfileRepository profileRepository,
    required UserProfile originalProfile,
  })  : _profileRepository = profileRepository,
        _originalProfile = originalProfile,
        super(const ProfileEditState());

  final ProfileRepository _profileRepository;
  final UserProfile _originalProfile;

  /// The original profile loaded when the editor was opened.
  UserProfile get originalProfile => _originalProfile;

  /// Updates a single field value and marks it as dirty.
  ///
  /// If the new value matches the original profile value, the field is
  /// removed from [dirtyFields] (it's no longer considered changed).
  void updateField(String fieldName, dynamic value) {
    final originalValue = _getOriginalFieldValue(fieldName);
    final newDirty = Map<String, dynamic>.from(state.dirtyFields);

    if (_valuesEqual(value, originalValue)) {
      // Value reverted to original — remove from dirty set
      newDirty.remove(fieldName);
    } else {
      newDirty[fieldName] = value;
    }

    // Clear any existing error for this field on edit
    final newErrors = Map<String, String?>.from(state.fieldErrors);
    newErrors.remove(fieldName);

    state = state.copyWith(
      dirtyFields: newDirty,
      fieldErrors: newErrors,
      isSuccess: false,
      clearSaveError: true,
    );
  }

  /// Validates all dirty fields and returns true if validation passes.
  ///
  /// Populates [ProfileEditState.fieldErrors] with any validation failures.
  bool validate() {
    final errors = <String, String?>{};

    for (final entry in state.dirtyFields.entries) {
      final error = _validateField(entry.key, entry.value);
      if (error != null) {
        errors[entry.key] = error;
      }
    }

    state = state.copyWith(fieldErrors: errors);
    return !state.hasErrors;
  }

  /// Saves the modified profile fields.
  ///
  /// 1. Validates all dirty fields — aborts if errors exist.
  /// 2. Builds an updated [UserProfile] merging dirty fields into the original.
  /// 3. Calls [ProfileRepository.updateProfile] (caching repo handles online/offline).
  /// 4. On success: sets [isSuccess] to true.
  /// 5. On failure: sets [saveError] with the error message.
  Future<void> save() async {
    // Nothing to save if no fields changed
    if (!state.isDirty) {
      state = state.copyWith(isSuccess: true);
      return;
    }

    // Step 1: Validate
    if (!validate()) return;

    // Step 2: Build updated profile
    final updatedProfile = _buildUpdatedProfile();

    // Step 3: Save via repository
    state = state.copyWith(isSaving: true, clearSaveError: true);

    final result = await _profileRepository.updateProfile(updatedProfile);

    // Step 4/5: Handle result
    switch (result) {
      case Success():
        state = state.copyWith(
          isSaving: false,
          isSuccess: true,
        );
      case Failure(error: final error):
        state = state.copyWith(
          isSaving: false,
          isSuccess: false,
          saveError: error.message,
        );
    }
  }

  /// Resets the form state, clearing all dirty fields and errors.
  void reset() {
    state = const ProfileEditState();
  }

  // --- Private helpers ---

  /// Validates a single field by name and value.
  /// Returns an error message or null if valid.
  String? _validateField(String fieldName, dynamic value) {
    switch (fieldName) {
      case 'name':
        final name = value as String?;
        if (name == null || name.trim().isEmpty) {
          return 'Name is required';
        }
        return null;

      case 'age':
        final age = value is int ? value : int.tryParse(value.toString());
        if (age == null || age < 13 || age > 120) {
          return 'Age must be between 13 and 120';
        }
        return null;

      case 'height_cm':
        final height =
            value is double ? value : double.tryParse(value.toString());
        if (height == null || height < 50 || height > 300) {
          return 'Height must be between 50 and 300 cm';
        }
        return null;

      case 'weight_kg':
        final weight =
            value is double ? value : double.tryParse(value.toString());
        if (weight == null || weight < 20 || weight > 500) {
          return 'Weight must be between 20 and 500 kg';
        }
        return null;

      default:
        // No validation rules for other fields (enums, lists)
        return null;
    }
  }

  /// Gets the original value for a given field name from the original profile.
  dynamic _getOriginalFieldValue(String fieldName) {
    switch (fieldName) {
      case 'name':
        return _originalProfile.name;
      case 'age':
        return _originalProfile.age;
      case 'height_cm':
        return _originalProfile.heightCm;
      case 'weight_kg':
        return _originalProfile.weightKg;
      case 'gender':
        return _originalProfile.gender;
      case 'fitness_goal':
        return _originalProfile.fitnessGoal;
      case 'fitness_level':
        return _originalProfile.fitnessLevel;
      case 'workout_preference':
        return _originalProfile.workoutPreference;
      case 'availability_days':
        return _originalProfile.workoutAvailability;
      default:
        return null;
    }
  }

  /// Builds an updated [UserProfile] by applying dirty fields to the original.
  UserProfile _buildUpdatedProfile() {
    final dirty = state.dirtyFields;

    return UserProfile(
      userId: _originalProfile.userId,
      name: dirty.containsKey('name')
          ? dirty['name'] as String
          : _originalProfile.name,
      age: dirty.containsKey('age')
          ? (dirty['age'] is int
              ? dirty['age'] as int
              : int.parse(dirty['age'].toString()))
          : _originalProfile.age,
      heightCm: dirty.containsKey('height_cm')
          ? (dirty['height_cm'] is double
              ? dirty['height_cm'] as double
              : double.parse(dirty['height_cm'].toString()))
          : _originalProfile.heightCm,
      weightKg: dirty.containsKey('weight_kg')
          ? (dirty['weight_kg'] is double
              ? dirty['weight_kg'] as double
              : double.parse(dirty['weight_kg'].toString()))
          : _originalProfile.weightKg,
      gender: dirty.containsKey('gender')
          ? dirty['gender'] as Gender
          : _originalProfile.gender,
      fitnessGoal: dirty.containsKey('fitness_goal')
          ? dirty['fitness_goal'] as FitnessGoal
          : _originalProfile.fitnessGoal,
      fitnessLevel: dirty.containsKey('fitness_level')
          ? dirty['fitness_level'] as FitnessLevel
          : _originalProfile.fitnessLevel,
      workoutPreference: dirty.containsKey('workout_preference')
          ? dirty['workout_preference'] as WorkoutPreference
          : _originalProfile.workoutPreference,
      workoutAvailability: dirty.containsKey('availability_days')
          ? (dirty['availability_days'] as List).cast<DayOfWeek>()
          : _originalProfile.workoutAvailability,
      updatedAt: DateTime.now(),
    );
  }

  /// Compares two values for equality, handling lists.
  bool _valuesEqual(dynamic a, dynamic b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }
}

/// Provider for the [ProfileEditNotifier].
///
/// Depends on [profileProvider] for the current user profile. When the profile
/// is available, creates a [ProfileEditNotifier] ready for editing. If no
/// profile is loaded yet, the provider throws — consumers should ensure the
/// profile is loaded before navigating to the edit screen.
final profileEditNotifierProvider =
    StateNotifierProvider.autoDispose<ProfileEditNotifier, ProfileEditState>(
        (ref) {
  final profileAsync = ref.watch(profileProvider);
  final profile = profileAsync.valueOrNull;

  if (profile == null) {
    throw StateError(
      'Cannot create ProfileEditNotifier without a loaded profile. '
      'Ensure the user profile is loaded before navigating to the edit screen.',
    );
  }

  final repository = ref.watch(profileRepositoryProvider);
  return ProfileEditNotifier(
    profileRepository: repository,
    originalProfile: profile,
  );
});
