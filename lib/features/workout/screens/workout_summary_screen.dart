import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/workout_provider.dart';

/// Displays the workout summary after all exercises are completed.
///
/// Shows total duration, exercises completed, and a congratulatory message.
///
/// Validates: Requirement 7.9
class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  bool _isSaving = true;
  bool _isSaved = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    // Save the completed session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveSession();
    });
  }

  Future<void> _saveSession() async {
    if (mounted) {
      setState(() {
        _isSaving = true;
        _saveError = null;
      });
    }
    final saved =
        await ref.read(workoutProvider.notifier).saveCompletedSession();
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isSaved = saved != null;
      _saveError = saved == null
          ? 'Could not save this workout. Check your connection and retry.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionState = ref.watch(workoutProvider);

    final totalDuration = sessionState.totalDurationSeconds;
    final exercisesCompleted = sessionState.exercisesCompletedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Complete'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const Spacer(),

            // Congratulatory icon
            Icon(
              Icons.emoji_events,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Congratulatory message
            Text(
              'Great Job!',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You completed your workout!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Stats cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: formatDuration(totalDuration),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatCard(
                    icon: Icons.fitness_center,
                    label: 'Exercises',
                    value: '$exercisesCompleted',
                  ),
                ),
              ],
            ),

            const Spacer(),

            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('Saving workout...'),
                  ],
                ),
              ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  _saveError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),

            // Done button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving
                    ? null
                    : _isSaved
                        ? () {
                            ref.read(workoutProvider.notifier).resetSession();
                            context.go('/dashboard');
                          }
                        : _saveSession,
                child: Text(_isSaved ? 'Done' : 'Retry Save'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
