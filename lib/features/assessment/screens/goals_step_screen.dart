import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/models/enums.dart';
import '../providers/assessment_provider.dart';

/// Step 3 of the assessment flow: fitness goal and training experience.
/// Final step that saves assessment data and navigates to Dashboard.
class GoalsStepScreen extends ConsumerStatefulWidget {
  const GoalsStepScreen({super.key});

  @override
  ConsumerState<GoalsStepScreen> createState() => _GoalsStepScreenState();
}

class _GoalsStepScreenState extends ConsumerState<GoalsStepScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _experienceController;
  FitnessGoal? _selectedGoal;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(assessmentProvider);
    _experienceController = TextEditingController(
      text: state.trainingExperienceYears != null
          ? state.trainingExperienceYears.toString()
          : '',
    );
    _selectedGoal = state.fitnessGoal;
  }

  @override
  void dispose() {
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _onFinish() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGoal == null) {
        setState(() {});
        return;
      }

      setState(() => _isSaving = true);

      final experience = int.parse(_experienceController.text.trim());
      final notifier = ref.read(assessmentProvider.notifier);
      notifier.updateStep3(_selectedGoal!, experience);

      final success = await notifier.saveAssessment();

      if (!mounted) return;

      setState(() => _isSaving = false);

      if (success) {
        context.go(RouteNames.dashboard);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save assessment. Please try again.'),
          ),
        );
      }
    }
  }

  void _onBack() {
    ref.read(assessmentProvider.notifier).goToStep(2);
    context.go('/assessment/2');
  }

  String _goalLabel(FitnessGoal goal) {
    return switch (goal) {
      FitnessGoal.loseWeight => 'Lose Weight',
      FitnessGoal.buildMuscle => 'Build Muscle',
      FitnessGoal.maintainFitness => 'Maintain Fitness',
      FitnessGoal.improveEndurance => 'Improve Endurance',
    };
  }

  String _goalDescription(FitnessGoal goal) {
    return switch (goal) {
      FitnessGoal.loseWeight => 'Focus on calorie burn and fat loss',
      FitnessGoal.buildMuscle => 'Strength training and muscle growth',
      FitnessGoal.maintainFitness => 'Keep your current fitness level',
      FitnessGoal.improveEndurance => 'Cardio and stamina improvement',
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
        title: const Text('Goals'),
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
                        'Set your fitness goals',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Choose your primary goal and tell us about your experience.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Fitness goal dropdown
                      DropdownButtonFormField<FitnessGoal>(
                        initialValue: _selectedGoal,
                        decoration: const InputDecoration(
                          labelText: 'Fitness Goal',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: FitnessGoal.values
                            .map((goal) => DropdownMenuItem(
                                  value: goal,
                                  child: Text(_goalLabel(goal)),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedGoal = value),
                        validator: (value) =>
                            value == null ? 'Please select a fitness goal' : null,
                      ),
                      if (_selectedGoal != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xxl),
                          child: Text(
                            _goalDescription(_selectedGoal!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),

                      // Training experience input
                      TextFormField(
                        controller: _experienceController,
                        decoration: const InputDecoration(
                          labelText: 'Training Experience (years)',
                          hintText: 'e.g. 3',
                          prefixIcon: Icon(Icons.history_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Training experience is required';
                          }
                          final years = int.tryParse(value.trim());
                          if (years == null) {
                            return 'Please enter a valid number';
                          }
                          if (years < 0 || years > 50) {
                            return 'Experience must be between 0 and 50 years';
                          }
                          return null;
                        },
                      ),

                      const Spacer(),
                      const SizedBox(height: AppSpacing.md),

                      // Finish button
                      FilledButton(
                        onPressed: _isSaving ? null : _onFinish,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Finish'),
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
              'Step 3 of 3',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: 3 / 3,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
