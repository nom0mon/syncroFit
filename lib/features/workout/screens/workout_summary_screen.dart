import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/safe_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/workout_provider.dart';

/// Displays the workout summary after all exercises are completed.
///
/// On first mount it checks whether a primary (non-bonus) session for the same
/// workout plan already exists this week.  If one is found the user is
/// prompted to either overwrite the existing log or save the current session
/// as a bonus extra.  If no duplicate is found the session is saved
/// automatically as a primary record.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSave();
    });
  }

  // ─── Save orchestration ──────────────────────────────────────────────────

  /// Entry point: fetch history, look for a duplicate, then decide.
  Future<void> _checkAndSave() async {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    // Fetch the current week's history so we can check for duplicates
    // client-side without adding a new repository query method.
    final notifier = ref.read(workoutProvider.notifier);
    final historyRepo = ref.read(workoutHistoryRepositoryProvider);
    final userId = ref.read(authStateProvider).user?.id ?? '';

    List<WorkoutHistory> allHistory = [];
    final histResult = await historyRepo.getAll(userId);
    if (histResult case Success(value: final records)) {
      allHistory = records;
    }

    final duplicate = await notifier.findDuplicateThisWeek(allHistory);

    if (!mounted) return;

    if (duplicate != null) {
      // A primary session for this plan already exists this week — ask user.
      await _showDuplicateDialog(duplicate);
    } else {
      // First completion this week — save normally as a primary session.
      await _performSave(() => notifier.saveCompletedSession());
    }
  }

  /// Shows the overwrite-vs-extra-session dialog and acts on the choice.
  Future<void> _showDuplicateDialog(WorkoutHistory existing) async {
    if (!mounted) return;

    final choice = await showDialog<_DuplicateChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SafeScrollableDialog(
        title: const Text('Already completed this week'),
        content: Text(
          'You have already logged "${existing.workoutName}" this week. '
          'What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_DuplicateChoice.extra),
            child: const Text('Save as Extra Session'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_DuplicateChoice.overwrite),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    final notifier = ref.read(workoutProvider.notifier);

    switch (choice) {
      case _DuplicateChoice.overwrite:
        await _performSave(() => notifier.overwriteSession(existing));
      case _DuplicateChoice.extra:
        await _performSave(() => notifier.saveAsExtraSession());
      case null:
        // Dialog dismissed without a choice — treat as extra session.
        await _performSave(() => notifier.saveAsExtraSession());
    }
  }

  /// Calls [saveAction], updates saving state, and surfaces any error.
  Future<void> _performSave(
    Future<WorkoutHistory?> Function() saveAction,
  ) async {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final saved = await saveAction();

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isSaved = saved != null;
      _saveError =
          saved == null ? 'Could not save this workout. Please retry.' : null;
    });
  }

  /// Retry handler — re-runs the full check-and-save flow.
  Future<void> _retry() => _checkAndSave();

  // ─── UI ─────────────────────────────────────────────────────────────────

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
      body: SafeArea(
        top: false,
        child: Padding(
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

              // Done / Retry button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving
                      ? null
                      : _isSaved
                          ? () {
                              ref
                                  .read(workoutProvider.notifier)
                                  .resetSession();
                              context.go('/dashboard');
                            }
                          : _retry,
                  child: Text(_isSaved ? 'Done' : 'Retry Save'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// The user's choice in the duplicate-resolution dialog.
enum _DuplicateChoice { overwrite, extra }

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
