import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/models/models.dart';

/// Helper extension to produce human-readable labels for enums.
extension GenderLabel on Gender {
  String get label => switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
      };
}

extension FitnessGoalLabel on FitnessGoal {
  String get label => switch (this) {
        FitnessGoal.loseWeight => 'Lose Weight',
        FitnessGoal.buildMuscle => 'Build Muscle',
        FitnessGoal.maintainFitness => 'Maintain Fitness',
        FitnessGoal.improveEndurance => 'Improve Endurance',
      };
}

extension FitnessLevelLabel on FitnessLevel {
  String get label => switch (this) {
        FitnessLevel.beginner => 'Beginner',
        FitnessLevel.intermediate => 'Intermediate',
        FitnessLevel.advanced => 'Advanced',
      };
}

extension WorkoutPreferenceLabel on WorkoutPreference {
  String get label => switch (this) {
        WorkoutPreference.home => 'Home',
        WorkoutPreference.gym => 'Gym',
        WorkoutPreference.outdoor => 'Outdoor',
      };
}

extension DayOfWeekLabel on DayOfWeek {
  String get label => switch (this) {
        DayOfWeek.monday => 'Mon',
        DayOfWeek.tuesday => 'Tue',
        DayOfWeek.wednesday => 'Wed',
        DayOfWeek.thursday => 'Thu',
        DayOfWeek.friday => 'Fri',
        DayOfWeek.saturday => 'Sat',
        DayOfWeek.sunday => 'Sun',
      };

  String get fullLabel => switch (this) {
        DayOfWeek.monday => 'Monday',
        DayOfWeek.tuesday => 'Tuesday',
        DayOfWeek.wednesday => 'Wednesday',
        DayOfWeek.thursday => 'Thursday',
        DayOfWeek.friday => 'Friday',
        DayOfWeek.saturday => 'Saturday',
        DayOfWeek.sunday => 'Sunday',
      };
}

/// A reusable profile form widget used by both ProfileSetupScreen and
/// ProfileEditScreen. Handles all input fields, validation, and exposes
/// the collected data via [onSubmit].
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    this.initialProfile,
    required this.onSubmit,
    required this.submitLabel,
    this.isLoading = false,
  });

  /// Pre-existing profile data to populate the form fields (for edit mode).
  final UserProfile? initialProfile;

  /// Called with the form data when validation passes.
  final void Function(ProfileFormData data) onSubmit;

  /// Label for the submit button (e.g., "Save Profile" or "Update Profile").
  final String submitLabel;

  /// Whether a save/update operation is in progress.
  final bool isLoading;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

/// Data class holding validated form values.
class ProfileFormData {
  const ProfileFormData({
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.gender,
    required this.fitnessGoal,
    required this.fitnessLevel,
    required this.workoutPreference,
    required this.workoutAvailability,
  });

  final String firstName;
  final String lastName;
  final int age;
  final double heightCm;
  final double weightKg;
  final Gender gender;
  final FitnessGoal fitnessGoal;
  final FitnessLevel fitnessLevel;
  final WorkoutPreference workoutPreference;
  final List<DayOfWeek> workoutAvailability;
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  Gender? _selectedGender;
  FitnessGoal? _selectedFitnessGoal;
  FitnessLevel? _selectedFitnessLevel;
  WorkoutPreference? _selectedWorkoutPreference;
  final Set<DayOfWeek> _selectedDays = {};

  String? _availabilityError;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;

    _firstNameController =
        TextEditingController(text: profile?.firstName ?? '');
    _lastNameController = TextEditingController(text: profile?.lastName ?? '');
    _ageController = TextEditingController(
      text: profile != null ? profile.age.toString() : '',
    );
    _heightController = TextEditingController(
      text: profile != null ? profile.heightCm.toString() : '',
    );
    _weightController = TextEditingController(
      text: profile != null ? profile.weightKg.toString() : '',
    );

    _selectedGender = profile?.gender;
    _selectedFitnessGoal = profile?.fitnessGoal;
    _selectedFitnessLevel = profile?.fitnessLevel;
    _selectedWorkoutPreference = profile?.workoutPreference;

    if (profile != null) {
      _selectedDays.addAll(profile.workoutAvailability);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final isFormValid = _formKey.currentState!.validate();

    // Validate availability separately
    setState(() {
      _availabilityError =
          _selectedDays.isEmpty ? 'Please select at least one day' : null;
    });

    if (!isFormValid || _selectedDays.isEmpty) return;

    widget.onSubmit(
      ProfileFormData(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        heightCm: double.parse(_heightController.text.trim()),
        weightKg: double.parse(_weightController.text.trim()),
        gender: _selectedGender!,
        fitnessGoal: _selectedFitnessGoal!,
        fitnessLevel: _selectedFitnessLevel!,
        workoutPreference: _selectedWorkoutPreference!,
        workoutAvailability: _selectedDays.toList()
          ..sort((a, b) => a.index.compareTo(b.index)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // First Name
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              hintText: 'Enter your first name',
            ),
            validator: validateName,
            textInputAction: TextInputAction.next,
            maxLength: 50,
          ),
          const SizedBox(height: AppSpacing.md),

          // Last Name
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              hintText: 'Enter your last name',
            ),
            validator: validateName,
            textInputAction: TextInputAction.next,
            maxLength: 50,
          ),
          const SizedBox(height: AppSpacing.md),

          // Age
          TextFormField(
            controller: _ageController,
            decoration: const InputDecoration(
              labelText: 'Age',
              hintText: 'Enter your age',
            ),
            keyboardType: TextInputType.number,
            validator: validateAge,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),

          // Height
          TextFormField(
            controller: _heightController,
            decoration: const InputDecoration(
              labelText: 'Height (cm)',
              hintText: 'Enter your height in cm',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: validateHeight,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),

          // Weight
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              hintText: 'Enter your weight in kg',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: validateWeight,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.md),

          // Gender dropdown
          DropdownButtonFormField<Gender>(
            initialValue: _selectedGender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: Gender.values
                .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                .toList(),
            onChanged: (value) => setState(() => _selectedGender = value),
            validator: (value) =>
                value == null ? 'Please select a gender' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Fitness Goal dropdown
          DropdownButtonFormField<FitnessGoal>(
            initialValue: _selectedFitnessGoal,
            decoration: const InputDecoration(labelText: 'Fitness Goal'),
            items: FitnessGoal.values
                .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                .toList(),
            onChanged: (value) => setState(() => _selectedFitnessGoal = value),
            validator: (value) =>
                value == null ? 'Please select a fitness goal' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Fitness Level dropdown
          DropdownButtonFormField<FitnessLevel>(
            initialValue: _selectedFitnessLevel,
            decoration: const InputDecoration(labelText: 'Fitness Level'),
            items: FitnessLevel.values
                .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                .toList(),
            onChanged: (value) => setState(() => _selectedFitnessLevel = value),
            validator: (value) =>
                value == null ? 'Please select a fitness level' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // Workout Preference dropdown
          DropdownButtonFormField<WorkoutPreference>(
            initialValue: _selectedWorkoutPreference,
            decoration: const InputDecoration(labelText: 'Workout Preference'),
            items: WorkoutPreference.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedWorkoutPreference = value),
            validator: (value) =>
                value == null ? 'Please select a workout preference' : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Workout Availability multi-select
          Text(
            'Workout Availability',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: DayOfWeek.values.map((day) {
              final isSelected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(day.label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                    // Clear error when user selects a day
                    if (_selectedDays.isNotEmpty) {
                      _availabilityError = null;
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (_availabilityError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _availabilityError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // Submit button
          SizedBox(
            height: AppSpacing.xxl,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _handleSubmit,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
