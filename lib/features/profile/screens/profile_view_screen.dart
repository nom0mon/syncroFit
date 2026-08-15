import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/models.dart';
import '../providers/profile_provider.dart';

/// Read-only screen that displays the user's profile information
/// organized into cards by section. Each section has an Edit button
/// that navigates to the profile edit screen.
class ProfileViewScreen extends ConsumerWidget {
  const ProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No profile yet'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/profile-setup'),
                    child: const Text('Set Up Profile'),
                  ),
                ],
              ),
            );
          }
          return _ProfileContent(profile: profile);
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header with avatar
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    profile.firstName.isNotEmpty
                        ? profile.firstName[0].toUpperCase()
                        : '?',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  profile.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Personal Information section
          _SectionCard(
            title: 'Personal Information',
            onEdit: () => context.push('/settings/edit-profile'),
            children: [
              _InfoRow(label: 'First Name', value: profile.firstName),
              _InfoRow(label: 'Last Name', value: profile.lastName),
              _InfoRow(label: 'Age', value: '${profile.age} years'),
              _InfoRow(
                  label: 'Gender', value: profile.gender.name._capitalize()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Body Measurements section
          _SectionCard(
            title: 'Body Measurements',
            onEdit: () => context.push('/settings/edit-profile'),
            children: [
              _InfoRow(label: 'Height', value: '${profile.heightCm} cm'),
              _InfoRow(label: 'Weight', value: '${profile.weightKg} kg'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Fitness Preferences section
          _SectionCard(
            title: 'Fitness Preferences',
            onEdit: () => context.push('/settings/edit-profile'),
            children: [
              _InfoRow(label: 'Goal', value: _goalLabel(profile.fitnessGoal)),
              _InfoRow(
                  label: 'Level',
                  value: profile.fitnessLevel.name._capitalize()),
              _InfoRow(
                  label: 'Preference',
                  value: profile.workoutPreference.name._capitalize()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Workout Schedule section
          _SectionCard(
            title: 'Workout Schedule',
            onEdit: () => context.push('/settings/edit-profile'),
            children: [
              _InfoRow(
                label: 'Available Days',
                value: profile.workoutAvailability
                    .map((d) => d.name._capitalize())
                    .join(', '),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _goalLabel(FitnessGoal goal) {
    switch (goal) {
      case FitnessGoal.loseWeight:
        return 'Lose Weight';
      case FitnessGoal.buildMuscle:
        return 'Build Muscle';
      case FitnessGoal.maintainFitness:
        return 'Stay Fit';
      case FitnessGoal.improveEndurance:
        return 'Improve Endurance';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.children, this.onEdit});
  final String title;
  final List<Widget> children;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

extension _StringCapitalize on String {
  String _capitalize() =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}
