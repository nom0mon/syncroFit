import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/trainer.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/consultation_provider.dart';

/// Displays a list of available trainers with name, specialization,
/// rating, and avatar placeholder.
///
/// Validates: Requirements 11.1, 11.2
class TrainerListScreen extends ConsumerWidget {
  const TrainerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(consultationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainers'),
      ),
      body: asyncState.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.invalidate(consultationProvider),
        ),
        data: (state) {
          if (state.errorMessage != null) {
            return ErrorDisplay(
              message: state.errorMessage!,
              onRetry: () => ref.invalidate(consultationProvider),
            );
          }

          if (state.trainers.isEmpty) {
            return const Center(
              child: Text('No trainers available'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.trainers.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              return _TrainerListItem(trainer: state.trainers[index]);
            },
          );
        },
      ),
    );
  }
}

/// Individual trainer card showing avatar, name, specialization, and rating.
/// Tapping navigates to the trainer profile screen (Req 11.2).
class _TrainerListItem extends StatelessWidget {
  const _TrainerListItem({required this.trainer});

  final Trainer trainer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () {
          context.go('/settings/trainers/${trainer.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Avatar placeholder
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  trainer.avatarPlaceholder,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Trainer info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      trainer.specialization,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    trainer.rating.toStringAsFixed(1),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
