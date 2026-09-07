import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/assessment_provider.dart';

/// Step 1 of the assessment flow: height and weight inputs with real-time BMI display.
class BmiStepScreen extends ConsumerStatefulWidget {
  const BmiStepScreen({super.key});

  @override
  ConsumerState<BmiStepScreen> createState() => _BmiStepScreenState();
}

class _BmiStepScreenState extends ConsumerState<BmiStepScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(assessmentProvider);
    _heightController = TextEditingController(
      text: state.heightCm != null ? state.heightCm.toString() : '',
    );
    _weightController = TextEditingController(
      text: state.weightKg != null ? state.weightKg.toString() : '',
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double? _calculatePreviewBmi() {
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (height != null && weight != null && height > 0) {
      final heightM = height / 100;
      final rawBmi = weight / (heightM * heightM);
      return (rawBmi * 10).roundToDouble() / 10;
    }
    return null;
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      final height = double.parse(_heightController.text.trim());
      final weight = double.parse(_weightController.text.trim());
      ref.read(assessmentProvider.notifier).updateStep1(height, weight);
      ref.read(assessmentProvider.notifier).goToStep(2);
      context.go('/assessment/2');
    }
  }

  void _onBack() {
    context.go(RouteNames.profileSetup);
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
        title: const Text('Body Measurements'),
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
                        'Enter your height and weight',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'We\'ll calculate your BMI to personalize your fitness plan.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Height input
                      TextFormField(
                        controller: _heightController,
                        decoration: const InputDecoration(
                          labelText: 'Height (cm)',
                          hintText: 'e.g. 175',
                          prefixIcon: Icon(Icons.height),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: validateHeight,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Weight input
                      TextFormField(
                        controller: _weightController,
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          hintText: 'e.g. 70',
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: validateWeight,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Real-time BMI display
                      _buildBmiDisplay(theme),

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
              'Step 1 of 3',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressIndicator(
          value: 1 / 3,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildBmiDisplay(ThemeData theme) {
    final bmi = _calculatePreviewBmi();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Your BMI',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            bmi != null ? bmi.toStringAsFixed(1) : '--',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (bmi != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _bmiCategory(bmi),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
