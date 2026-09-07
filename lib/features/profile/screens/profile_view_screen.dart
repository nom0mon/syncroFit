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
              const _SectionHeader(title: 'Physical Information'),
              const SizedBox(height: AppSpacing.sm),
              _InfoTable(rows: [
                _InfoRow(label: 'Age', value: '${profile.age} years'),
                _InfoRow(label: 'Height', value: '${profile.heightCm} cm'),
                _InfoRow(label: 'Weight', value: '${profile.weightKg} kg'),
                _InfoRow(label: 'Gender', value: profile.gender.label),
              ]),
              const SizedBox(height: AppSpacing.lg),

              // Fitness info section
              const _SectionHeader(title: 'Fitness Settings'),
              const SizedBox(height: AppSpacing.sm),
              _InfoTable(rows: [
                _InfoRow(label: 'Goal', value: profile.fitnessGoal.label),
                _InfoRow(label: 'Level', value: profile.fitnessLevel.label),
                _InfoRow(
                  label: 'Preference',
                  value: profile.workoutPreference.label,
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),

              // Availability section
              const _SectionHeader(title: 'Workout Availability'),
              const SizedBox(height: AppSpacing.sm),
              _InfoTable(rows: [
                _InfoRow(
                  label: 'Available Days',
                  value: profile.workoutAvailability
                      .map((day) => day.fullLabel)
                      .join(', '),
                ),
              ]),
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

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.4),
          1: FlexColumnWidth(0.6),
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        children: rows.map((row) => row.buildTableRow(context)).toList(),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  TableRow buildTableRow(BuildContext context) {
    final theme = Theme.of(context);
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ]);
  }
}
