import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/models/enums.dart';
import '../providers/assessment_provider.dart';

/// Step 2 of the assessment flow: age, gender, and activity level.
class PhysicalInfoStepScreen extends ConsumerStatefulWidget {
  const PhysicalInfoStepScreen({super.key});

  @override
  ConsumerState<PhysicalInfoStepScreen> createState() =>
      _PhysicalInfoStepScreenState();
}

class _PhysicalInfoStepScreenState
    extends ConsumerState<PhysicalInfoStepScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageController;
  Gender? _selectedGender;
  ActivityLevel? _selectedActivityLevel;

  @override
  void initState() {
    super.initState();
    final state = ref.read(assessmentProvider);
    _ageController = TextEditingController(
      text: state.age != null ? state.age.toString() : '',
    );
    _selectedGender = state.gender;
    _selectedActivityLevel = state.activityLevel;
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null || _selectedActivityLevel == null) {
        // Trigger validation display
        setState(() {});
        return;
      }
      final age = int.parse(_ageController.text.trim());
      ref
          .read(assessmentProvider.notifier)
          .updateStep2(age, _selectedGender!, _selectedActivityLevel!);
      ref.read(assessmentProvider.notifier).goToStep(3);
      context.go('/assessment/3');
    }
  }

  void _onBack() {
    ref.read(assessmentProvider.notifier).goToStep(1);
    context.go('/assessment/1');
  }

  String _genderLabel(Gender gender) {
    return switch (gender) {
      Gender.male => 'Male',
      Gender.female => 'Female',
      Gender.other => 'Other',
    };
  }

  String _activityLevelLabel(ActivityLevel level) {
    return switch (level) {
      ActivityLevel.sedentary => 'Sedentary',
      ActivityLevel.lightlyActive => 'Lightly Active',
      ActivityLevel.moderatelyActive => 'Moderately Active',
      ActivityLevel.veryActive => 'Very Active',
    };
  }

  String _activityLevelDescription(ActivityLevel level) {
    return switch (level) {
      ActivityLevel.sedentary => 'Little or no exercise',
      ActivityLevel.lightlyActive => 'Light exercise 1-3 days/week',
      ActivityLevel.moderatelyActive => 'Moderate exercise 3-5 days/week',
      ActivityLevel.veryActive => 'Hard exercise 6-7 days/week',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBack,
        ),
        title: const Text('Physical Info'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress indicator
                      _buildProgressIndicator(theme),
                      const SizedBox(height: AppSpacing.lg),

                      Text(
                        'Tell us about yourself',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'This helps us tailor workout recommendations to your needs.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Age input
                      TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          hintText: 'e.g. 28',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: validateAge,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Gender dropdown
                      DropdownButtonFormField<Gender>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: Gender.values
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(_genderLabel(g)),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedGender = value),
                        validator: (value) =>
                            value == null ? 'Please select a gender' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Activity level dropdown
                      DropdownButtonFormField<ActivityLevel>(
                        initialValue: _selectedActivityLevel,
                        decoration: const InputDecoration(
                          labelText: 'Activity Level',
                          prefixIcon: Icon(Icons.directions_run_outlined),
                        ),
                        items: ActivityLevel.values
                            .map((level) => DropdownMenuItem(
                                  value: level,
                                  child: Text(_activityLevelLabel(level)),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedActivityLevel = value),
                        validator: (value) =>
                            value == null ? 'Please select an activity level' : null,
                      ),
                      if (_selectedActivityLevel != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xxl),
                          child: Text(
                            _activityLevelDescription(_selectedActivityLevel!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],

                      const Spacer(),
                      const SizedBox(height: AppSpacing.md),

                      // Next button
                      FilledButton(
                        onPressed: _onNext,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Step 2 of 3',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: 2 / 3,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
