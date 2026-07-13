import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/trainer.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/consultation_provider.dart';

/// Displays the full profile of a trainer including name, bio, specialization,
/// rating, experience, available slots, and avatar placeholder.
/// Includes a "Book Consultation" button to navigate to the booking form.
///
/// Validates: Requirements 11.3
class TrainerProfileScreen extends ConsumerWidget {
  const TrainerProfileScreen({required this.trainerId, super.key});

  final String trainerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainerAsync = ref.watch(trainerDetailProvider(trainerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Profile'),
      ),
      body: trainerAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
        data: (trainer) {
          if (trainer == null) {
            return const Center(
              child: Text('Trainer not found'),
            );
          }

          return _TrainerProfileContent(trainer: trainer);
        },
      ),
    );
  }
}

class _TrainerProfileContent extends StatelessWidget {
  const _TrainerProfileContent({required this.trainer});

  final Trainer trainer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and name header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    trainer.avatarPlaceholder,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  trainer.name,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  trainer.specialization,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Rating and experience row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatCard(
                icon: Icons.star,
                label: 'Rating',
                value: trainer.rating.toStringAsFixed(1),
              ),
              _StatCard(
                icon: Icons.work_history_outlined,
                label: 'Experience',
                value: '${trainer.experienceYears} yrs',
              ),
              _StatCard(
                icon: Icons.calendar_today_outlined,
                label: 'Slots',
                value: '${trainer.availableSlots.where((s) => !s.isBooked).length}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Bio section
          Text(
            'About',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            trainer.bio,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Available slots section
          Text(
            'Available Time Slots',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: trainer.availableSlots
                .where((slot) => !slot.isBooked)
                .map((slot) => Chip(
                      label: Text(
                        '${slot.date.month}/${slot.date.day} ${slot.time}',
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Book Consultation button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                context.go('/settings/trainers/${trainer.id}/book');
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Book Consultation'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// A compact stat display card used in the profile header.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
