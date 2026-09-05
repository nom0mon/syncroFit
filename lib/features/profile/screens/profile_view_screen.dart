import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_form.dart'
    show
        GenderLabel,
        FitnessGoalLabel,
        FitnessLevelLabel,
        WorkoutPreferenceLabel,
        DayOfWeekLabel;

/// Read-only screen displaying the authenticated user's profile information.
///
/// Shows all profile fields in a clean layout with an "Edit" button
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
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text(
          'My Profile',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          profileAsync.whenOrNull(
                data: (profile) => profile != null
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => context.push('/settings/edit-profile'),
                        tooltip: 'Edit Profile',
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline, size: 64),
                  const SizedBox(height: AppSpacing.md),
                  const Text('No profile set up yet'),
                  const SizedBox(height: AppSpacing.md),
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

    return SafeArea(
      child: ResponsiveConstrainedPage(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        profile.name.isNotEmpty
                            ? profile.name[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      profile.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Physical info section
              _SectionHeader(title: 'Physical Information'),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(label: 'Age', value: '${profile.age} years'),
              _InfoRow(label: 'Height', value: '${profile.heightCm} cm'),
              _InfoRow(label: 'Weight', value: '${profile.weightKg} kg'),
              _InfoRow(label: 'Gender', value: profile.gender.label),
              const SizedBox(height: AppSpacing.lg),

              // Fitness info section
              _SectionHeader(title: 'Fitness Settings'),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(label: 'Goal', value: profile.fitnessGoal.label),
              _InfoRow(label: 'Level', value: profile.fitnessLevel.label),
              _InfoRow(
                label: 'Preference',
                value: profile.workoutPreference.label,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Availability section
              _SectionHeader(title: 'Workout Availability'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: profile.workoutAvailability.map((day) {
                  return Chip(
                    label: Text(day.fullLabel),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackValues =
            ResponsiveStandards.widthClassFor(constraints.maxWidth) ==
                    AppWidthClass.compact ||
                textScale >= 1.5;
        final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            );
        final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: stackValues
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: labelStyle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(value, style: valueStyle),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(label, style: labelStyle)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: valueStyle,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
