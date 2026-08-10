import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/models.dart';
import '../providers/profile_edit_notifier.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_form.dart'
    show
        GenderLabel,
        FitnessGoalLabel,
        FitnessLevelLabel,
        WorkoutPreferenceLabel,
        DayOfWeekLabel;

/// Screen for editing an existing user profile using dirty-field tracking.
///
/// Uses [ProfileEditNotifier] for PATCH-style edits: only changed fields
/// are sent to the backend. Displays inline validation errors from
/// [ProfileEditState.fieldErrors] and shows a loading overlay during save.
/// Navigates back on successful save.
///
/// Handles the case where the profile hasn't loaded yet by showing a loading
/// state, and redirects to profile setup if the profile is null.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: Center(child: Text('Failed to load profile: $error')),
      ),
      data: (profile) {
        if (profile == null) {
          // Profile doesn't exist yet — redirect to profile setup
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/profile-setup');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _ProfileEditContent(profile: profile);
      },
    );
  }
}

/// The actual profile edit form content, only rendered when a profile is loaded.
class _ProfileEditContent extends ConsumerStatefulWidget {
  const _ProfileEditContent({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileEditContent> createState() =>
      _ProfileEditContentState();
}

class _ProfileEditContentState extends ConsumerState<_ProfileEditContent> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _initControllers(UserProfile profile) {
    if (_initialized) return;
    _initialized = true;

    _nameController = TextEditingController(text: profile.name);
    _ageController = TextEditingController(text: profile.age.toString());
    _heightController =
        TextEditingController(text: profile.heightCm.toString());
    _weightController =
        TextEditingController(text: profile.weightKg.toString());

    // Listen to text field changes and update dirty fields
    _nameController.addListener(() {
      ref
          .read(profileEditNotifierProvider.notifier)
          .updateField('name', _nameController.text.trim());
    });
    _ageController.addListener(() {
      final text = _ageController.text.trim();
      final value = int.tryParse(text);
      ref
          .read(profileEditNotifierProvider.notifier)
          .updateField('age', value ?? text);
    });
    _heightController.addListener(() {
      final text = _heightController.text.trim();
      final value = double.tryParse(text);
      ref
          .read(profileEditNotifierProvider.notifier)
          .updateField('height_cm', value ?? text);
    });
    _weightController.addListener(() {
      final text = _weightController.text.trim();
      final value = double.tryParse(text);
      ref
          .read(profileEditNotifierProvider.notifier)
          .updateField('weight_kg', value ?? text);
    });
  }

  Future<void> _handleSave() async {
    await ref.read(profileEditNotifierProvider.notifier).save();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileEditNotifierProvider);
    final notifier = ref.read(profileEditNotifierProvider.notifier);
    final profile = notifier.originalProfile;

    _initControllers(profile);

    // Navigate back on successful save
    ref.listen<ProfileEditState>(profileEditNotifierProvider, (previous, next) {
      if (next.isSuccess && !(previous?.isSuccess ?? false)) {
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: state.isSaving ? null : _handleSave,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name field
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter your name',
                    errorText: state.fieldErrors['name'],
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),

                // Age field
                TextField(
                  controller: _ageController,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    hintText: 'Enter your age',
                    errorText: state.fieldErrors['age'],
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),

                // Height field
                TextField(
                  controller: _heightController,
                  decoration: InputDecoration(
                    labelText: 'Height (cm)',
                    hintText: 'Enter your height in cm',
                    errorText: state.fieldErrors['height_cm'],
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),

                // Weight field
                TextField(
                  controller: _weightController,
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'Enter your weight in kg',
                    errorText: state.fieldErrors['weight_kg'],
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.md),

                // Gender dropdown
                DropdownButtonFormField<Gender>(
                  value: _currentGender(state, profile),
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    errorText: state.fieldErrors['gender'],
                  ),
                  items: Gender.values
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      notifier.updateField('gender', value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Fitness Goal dropdown
                DropdownButtonFormField<FitnessGoal>(
                  value: _currentFitnessGoal(state, profile),
                  decoration: InputDecoration(
                    labelText: 'Fitness Goal',
                    errorText: state.fieldErrors['fitness_goal'],
                  ),
                  items: FitnessGoal.values
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      notifier.updateField('fitness_goal', value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Fitness Level dropdown
                DropdownButtonFormField<FitnessLevel>(
                  value: _currentFitnessLevel(state, profile),
                  decoration: InputDecoration(
                    labelText: 'Fitness Level',
                    errorText: state.fieldErrors['fitness_level'],
                  ),
                  items: FitnessLevel.values
                      .map((l) =>
                          DropdownMenuItem(value: l, child: Text(l.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      notifier.updateField('fitness_level', value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Workout Preference dropdown
                DropdownButtonFormField<WorkoutPreference>(
                  value: _currentWorkoutPreference(state, profile),
                  decoration: InputDecoration(
                    labelText: 'Workout Preference',
                    errorText: state.fieldErrors['workout_preference'],
                  ),
                  items: WorkoutPreference.values
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      notifier.updateField('workout_preference', value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Availability Days multi-select chips
                Text(
                  'Workout Availability',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: DayOfWeek.values.map((day) {
                    final selectedDays =
                        _currentAvailabilityDays(state, profile);
                    final isSelected = selectedDays.contains(day);
                    return FilterChip(
                      label: Text(day.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        final updated = List<DayOfWeek>.from(selectedDays);
                        if (selected) {
                          updated.add(day);
                        } else {
                          updated.remove(day);
                        }
                        // Sort to maintain consistent order
                        updated.sort((a, b) => a.index.compareTo(b.index));
                        notifier.updateField('availability_days', updated);
                      },
                    );
                  }).toList(),
                ),
                if (state.fieldErrors['availability_days'] != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    state.fieldErrors['availability_days']!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],

                // Save error message
                if (state.saveError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    state.saveError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),

          // Loading overlay
          if (state.isSaving)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // --- Helpers to get current field values (dirty or original) ---

  Gender _currentGender(ProfileEditState state, UserProfile profile) {
    if (state.dirtyFields.containsKey('gender')) {
      return state.dirtyFields['gender'] as Gender;
    }
    return profile.gender;
  }

  FitnessGoal _currentFitnessGoal(ProfileEditState state, UserProfile profile) {
    if (state.dirtyFields.containsKey('fitness_goal')) {
      return state.dirtyFields['fitness_goal'] as FitnessGoal;
    }
    return profile.fitnessGoal;
  }

  FitnessLevel _currentFitnessLevel(
      ProfileEditState state, UserProfile profile) {
    if (state.dirtyFields.containsKey('fitness_level')) {
      return state.dirtyFields['fitness_level'] as FitnessLevel;
    }
    return profile.fitnessLevel;
  }

  WorkoutPreference _currentWorkoutPreference(
      ProfileEditState state, UserProfile profile) {
    if (state.dirtyFields.containsKey('workout_preference')) {
      return state.dirtyFields['workout_preference'] as WorkoutPreference;
    }
    return profile.workoutPreference;
  }

  List<DayOfWeek> _currentAvailabilityDays(
      ProfileEditState state, UserProfile profile) {
    if (state.dirtyFields.containsKey('availability_days')) {
      return (state.dirtyFields['availability_days'] as List).cast<DayOfWeek>();
    }
    return profile.workoutAvailability;
  }
}
