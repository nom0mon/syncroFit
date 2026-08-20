import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/models.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_form.dart';

/// Screen for initial profile setup during onboarding.
///
/// If the user already has a profile, redirects to the dashboard.
/// Otherwise, collects all required profile fields and saves via [ProfileNotifier].
/// On successful save, navigates to the first assessment step.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  bool _isSaving = false;

  Future<void> _handleSubmit(ProfileFormData data) async {
    setState(() => _isSaving = true);

    // Use the authenticated user's ID from the auth state
    final authState = ref.read(authStateProvider);
    final userId = authState.user?.id ?? '';

    final profile = UserProfile(
      userId: userId,
      firstName: data.firstName,
      lastName: data.lastName,
      age: data.age,
      heightCm: data.heightCm,
      weightKg: data.weightKg,
      gender: data.gender,
      fitnessGoal: data.fitnessGoal,
      fitnessLevel: data.fitnessLevel,
      workoutPreference: data.workoutPreference,
      workoutAvailability: data.workoutAvailability,
    );

    await ref.read(profileProvider.notifier).saveProfile(profile);

    if (!mounted) return;

    final state = ref.read(profileProvider);
    if (state.hasError) {
      setState(() => _isSaving = false);
      final error = state.error;
      // If profile already exists (409), redirect to profile view
      if (error is ServerError && error.statusCode == 409) {
        context.go('/settings/profile');
        return;
      }
      final errorMessage = error is AppError
          ? error.message
          : error.toString();
      debugPrint('Profile save error: ${state.error}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $errorMessage'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    context.go('/assessment/1');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Back',
          ),
          title: const Text('Profile Setup'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildSetupForm(),
      data: (profile) {
        if (profile != null) {
          // Profile already exists — redirect to profile view
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/settings/profile');
          });
          return Scaffold(
            appBar: AppBar(title: const Text('Profile Setup')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return _buildSetupForm();
      },
    );
  }

  Widget _buildSetupForm() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Profile Setup'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ProfileForm(
            onSubmit: _handleSubmit,
            submitLabel: 'Save Profile',
            isLoading: _isSaving,
          ),
        ),
      ),
    );
  }
}
