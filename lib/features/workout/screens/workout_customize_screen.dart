import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../exercise_library/providers/exercise_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart' as dashboard;
import '../../progress/providers/progress_provider.dart' as progress;
import '../../profile/providers/profile_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/workout_scheduler_provider.dart';

class WorkoutCustomizeScreen extends ConsumerStatefulWidget {
  const WorkoutCustomizeScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  ConsumerState<WorkoutCustomizeScreen> createState() =>
      _WorkoutCustomizeScreenState();
}

class _WorkoutCustomizeScreenState
    extends ConsumerState<WorkoutCustomizeScreen> {
  /// Editable copy of the workout's exercises, one entry per exercise slot.
  List<_EditableExercise>? _editable;

  /// The coach-validated exercises captured before customization, used to
  /// detect deviation and restore the recommended plan.
  List<WorkoutExercise>? _baseline;

  /// The exercise IDs from the workout as it was loaded, used to detect
  /// whether the exercise list needs syncing to the server.
  List<int>? _originalIds;

  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(workoutByIdProvider(widget.workoutId));
    final library = ref.watch(exerciseProvider);
    final environment =
        ref.watch(profileProvider).valueOrNull?.workoutPreference.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Workout'),
        actions: [
          if (_baseline != null)
            IconButton(
              tooltip: 'Restore Recommended Plan',
              icon: const Icon(Icons.restart_alt),
              onPressed: _restoreBaseline,
            ),
        ],
      ),
      body: workoutAsync.when(
        loading: () => const LoadingIndicator(),
        error: (_, __) =>
            const Center(child: Text('Unable to load workout.')),
        data: (workout) {
          if (workout == null) {
            return const Center(child: Text('Workout not found.'));
          }
          // Initialize editable state from the workout (once).
          _editable ??= [
            for (final e in workout.exercises) _EditableExercise.from(e),
          ];
          _baseline ??= workout.baselineExercises ?? workout.exercises;
          _originalIds ??=
              workout.exercises.map((e) => e.exerciseId).toList();

          final byId = <int, Exercise>{
            for (final exercise in library.allExercises)
              if (int.tryParse(exercise.id) case final int id) id: exercise,
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Text(
                  'Add, remove, or reorder exercises. Adjust sets, reps, and '
                  'rest to match your daily readiness.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _editable!.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) => setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    _editable!.insert(newIndex, _editable!.removeAt(oldIndex));
                  }),
                  itemBuilder: (context, index) {
                    final e = _editable![index];
                    final exercise = byId[e.exerciseId];
                    return _ExerciseEditCard(
                      key: ValueKey(e.exerciseId),
                      exercise: e,
                      name: exercise?.name ?? 'Exercise ${e.exerciseId}',
                      subtitle: exercise?.displayMuscleGroup,
                      canRemove: _editable!.length > 1,
                      onRemove: () =>
                          setState(() => _editable!.removeAt(index)),
                      onChanged: () => setState(() {}),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: library.isLoading
                          ? null
                          : () => _pick(library.allExercises, environment),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Exercise'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Reverts all edits back to the coach's original validated parameters.
  void _restoreBaseline() {
    setState(() {
      _editable = [for (final e in _baseline!) _EditableExercise.from(e)];
    });
  }

  Future<void> _pick(List<Exercise> exercises, String? environment) async {
    // Infer the workout's own environment from the equipment of its existing
    // exercises, rather than using the profile's current preference which may
    // differ from the environment the workout was generated for.
    // Priority: if any existing exercise uses non-bodyweight equipment, the
    // workout is a gym workout. If all are bodyweight/pull_up_bar, fall back
    // to the profile preference, which may itself be 'home' or 'outdoor'.
    final byId = <int, Exercise>{
      for (final e in exercises)
        if (int.tryParse(e.id) case final int id) id: e,
    };
    final workoutEnvironment = _inferWorkoutEnvironment(_editable!, byId, environment);

    final available = exercises
        .where((exercise) => !_editable!
            .any((e) => e.exerciseId == int.tryParse(exercise.id)))
        .where((exercise) =>
            workoutEnvironment == null ||
            exercise.environments.contains(workoutEnvironment))
        .toList();

    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: available.isEmpty
              ? Center(
                  child: Text(workoutEnvironment == null
                      ? 'No more exercises available.'
                      : 'No more exercises are available for your selected environment.'),
                )
              : ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(available[index].name),
                    subtitle: Text(available[index].displayMuscleGroup),
                    onTap: () => Navigator.pop(
                        context, int.parse(available[index].id)),
                  ),
                ),
        ),
      ),
    );

    if (selected != null && mounted) {
      final exercise = available.firstWhere(
        (e) => int.parse(e.id) == selected,
        orElse: () => available.first,
      );
      setState(() {
        _editable!.add(_EditableExercise(
          exerciseId: selected,
          sets: exercise.defaultSets > 0 ? exercise.defaultSets : 3,
          reps: exercise.defaultReps > 0 ? exercise.defaultReps : 10,
          durationSeconds: exercise.defaultDurationSeconds,
          restSeconds: 120,
        ));
      });
    }
  }

  Future<void> _save() async {
    final repository = ref.read(workoutRepositoryProvider);
    if (repository is! WorkoutCustomizationRepository) return;

    setState(() => _saving = true);

    // Build the final exercise list with sequential order values.
    final exercises = [
      for (int i = 0; i < _editable!.length; i++)
        _editable![i].toWorkoutExercise(i + 1),
    ];
    final exerciseIds = [for (final e in _editable!) e.exerciseId];

    // Determine if the exercise ID list changed from what the workout
    // currently has (including a restore that differs from the server's
    // current list).
    final idsChanged = !_intListEquals(_originalIds!, exerciseIds);

    // 1. If the exercise list changed, sync to the server. The backend
    //    recomputes sets/reps/rest from the profile, so this call also
    //    refreshes the local cache.
    if (idsChanged) {
      final result = await (repository as WorkoutCustomizationRepository)
          .customizeExercises(widget.workoutId, exerciseIds);
      if (!mounted) return;
      if (result is Failure<Workout, AppError>) {
        setState(() => _saving = false);
        _showError(result.error);
        return;
      }
    }

    // 2. Apply the user's parameter overrides (sets/reps/rest) locally and
    //    store the baseline so "Restore" and the "Customized" chip work.
    final localResult =
        await (repository as WorkoutCustomizationRepository)
            .saveLocalCustomization(
      widget.workoutId,
      exercises,
      _baseline!,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    switch (localResult) {
      case Success():
        ref.invalidate(workoutByIdProvider(widget.workoutId));
        ref.invalidate(workoutSchedulerProvider);
        ref.invalidate(dashboard.dashboardProvider);
        ref.invalidate(progress.progressProvider);
        Navigator.pop(context);
      case Failure(error: final error):
        _showError(error);
    }
  }

  void _showError(AppError error) {
    final message = error is NetworkError
        ? 'Workout customization requires a connection. Your existing workout was not changed.'
        : error is ValidationError && error.fieldErrors.isNotEmpty
            ? error.fieldErrors.values.first
            : error.message;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static bool _intListEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Infers the workout's training environment from the equipment of its
  /// existing exercises.
  ///
  /// If any exercise in the workout uses gym equipment (anything other than
  /// 'bodyweight' or 'pull_up_bar'), the workout is treated as a gym workout.
  /// This prevents the picker from incorrectly filtering out gym exercises
  /// when the user's profile preference was later changed to 'home' or
  /// 'outdoor' after the workout was originally generated.
  ///
  /// Falls back to [profileEnvironment] when the exercise library is not yet
  /// loaded or all exercises are bodyweight-only.
  static String? _inferWorkoutEnvironment(
    List<_EditableExercise> editable,
    Map<int, Exercise> byId,
    String? profileEnvironment,
  ) {
    for (final e in editable) {
      final exercise = byId[e.exerciseId];
      if (exercise == null) continue;
      final equipment = exercise.equipment?.toLowerCase() ?? '';
      if (equipment.isNotEmpty &&
          equipment != 'bodyweight' &&
          equipment != 'pull_up_bar') {
        return 'gym';
      }
    }
    return profileEnvironment;
  }
}

/// Mutable copy of a [WorkoutExercise] used for in-place editing.
class _EditableExercise {
  _EditableExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.durationSeconds,
    required this.restSeconds,
  });

  final int exerciseId;
  int sets;
  int reps;
  int durationSeconds;
  int restSeconds;

  factory _EditableExercise.from(WorkoutExercise e) => _EditableExercise(
        exerciseId: e.exerciseId,
        sets: e.sets,
        reps: e.reps,
        durationSeconds: e.durationSeconds,
        restSeconds: e.restSeconds,
      );

  WorkoutExercise toWorkoutExercise(int order) => WorkoutExercise(
        exerciseId: exerciseId,
        sets: sets,
        reps: reps,
        durationSeconds: durationSeconds,
        restSeconds: restSeconds,
        order: order,
      );
}

/// A card showing one editable exercise with sets/reps/rest controls.
class _ExerciseEditCard extends StatelessWidget {
  const _ExerciseEditCard({
    super.key,
    required this.exercise,
    required this.name,
    this.subtitle,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _EditableExercise exercise;
  final String name;
  final String? subtitle;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDuration = exercise.durationSeconds > 0;

    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.drag_handle),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium,
                        softWrap: true,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove exercise',
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  // Compact density keeps the button from pushing the card
                  // height up unnecessarily.
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Wrap lets the steppers reflow to a second line on narrow cards
            // instead of overflowing the card boundary.
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _Stepper(
                  label: 'Sets',
                  value: exercise.sets,
                  min: 1,
                  max: 10,
                  onChanged: (v) {
                    exercise.sets = v;
                    onChanged();
                  },
                ),
                if (isDuration)
                  _Stepper(
                    label: 'Seconds',
                    value: exercise.durationSeconds,
                    min: 5,
                    max: 600,
                    step: 5,
                    onChanged: (v) {
                      exercise.durationSeconds = v;
                      onChanged();
                    },
                  )
                else
                  _Stepper(
                    label: 'Reps',
                    value: exercise.reps,
                    min: 1,
                    max: 100,
                    onChanged: (v) {
                      exercise.reps = v;
                      onChanged();
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Rest', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [60, 90, 120, 150].map((rest) {
                return ChoiceChip(
                  label: Text('${rest}s'),
                  selected: exercise.restSeconds == rest,
                  onSelected: (_) {
                    exercise.restSeconds = rest;
                    onChanged();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact [- value +] stepper for integer fields.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 100,
    this.step = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - step) : null,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + step) : null,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
        ),
      ],
    );
  }
}
