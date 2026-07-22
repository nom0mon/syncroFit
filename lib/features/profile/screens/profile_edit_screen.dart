import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/models.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_form.dart';

/// Screen for editing an existing user profile.
///
/// Loads the current profile from [profileProvider], pre-populates the form,
/// and calls [ProfileNotifier.updateProfile] on valid submit.
/// Shows a SnackBar confirmation on successful update.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  bool _isSaving = false;

  Future<void> _handleSubmit(ProfileFormData data, UserProfile existing) async {
    setState(() => _isSaving = true);

    final updatedProfile = UserProfile(
      userId: existing.userId,
      name: data.name,
      age: data.age,
      heightCm: data.heightCm,
      weightKg: data.weightKg,
      gender: data.gender,
      fitnessGoal: data.fitnessGoal,
      fitnessLevel: data.fitnessLevel,
      workoutPreference: data.workoutPreference,
      workoutAvailability: data.workoutAvailability,
    );

    await ref.read(profileProvider.notifier).updateProfile(updatedProfile);

    if (!mounted) return;

    final state = ref.read(profileProvider);
    if (state.hasError) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile. Please try again.')),
      );
      return;
    }

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Failed to load profile',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(profileProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text('No profile found. Please set up your profile first.'),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ProfileForm(
                initialProfile: profile,
                onSubmit: (data) => _handleSubmit(data, profile),
                submitLabel: 'Update Profile',
                isLoading: _isSaving,
              ),
            );
          },
        ),
      ),
    );
  }
}
