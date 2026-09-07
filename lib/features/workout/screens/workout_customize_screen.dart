import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../exercise_library/providers/exercise_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart' as dashboard;
import '../../progress/providers/progress_provider.dart' as progress;
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
  List<int>? _ids;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(workoutByIdProvider(widget.workoutId));
    final library = ref.watch(exerciseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Customize Workout')),
      body: workoutAsync.when(
        loading: () => const LoadingIndicator(),
        error: (_, __) => const Center(child: Text('Unable to load workout.')),
        data: (workout) {
          if (workout == null) {
            return const Center(child: Text('Workout not found.'));
          }
          _ids ??= workout.exercises.map((item) => item.exerciseId).toList();
          final byId = <int, Exercise>{
            for (final exercise in library.allExercises)
              if (int.tryParse(exercise.id) case final int id) id: exercise,
          };
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Text(
                  'Add, remove, or drag exercises into order. Sets, reps, and rest are assigned automatically.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _ids!.length,
                // ignore: deprecated_member_use
                onReorder: (oldIndex, newIndex) => setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  _ids!.insert(newIndex, _ids!.removeAt(oldIndex));
                }),
                itemBuilder: (context, index) {
                  final id = _ids![index];
                  final exercise = byId[id];
                  return Card(
                    key: ValueKey(id),
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle),
                      title: Text(exercise?.name ?? 'Exercise $id'),
                      subtitle: Text(exercise?.muscleGroup ?? 'Unavailable'),
                      trailing: IconButton(
                        tooltip: 'Remove exercise',
                        onPressed: _ids!.length == 1
                            ? null
                            : () => setState(() => _ids!.remove(id)),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ),
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
                          : () => _pick(library.allExercises),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Exercise'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ]),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _pick(List<Exercise> exercises) async {
    final available =
        exercises.where((e) => !_ids!.contains(int.tryParse(e.id))).toList();
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: available.isEmpty
              ? const Center(child: Text('No more exercises available.'))
              : ListView.builder(
                  itemCount: available.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(available[index].name),
                    subtitle: Text(available[index].muscleGroup),
                    onTap: () =>
                        Navigator.pop(context, int.parse(available[index].id)),
                  ),
                ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _ids!.add(selected));
  }

  Future<void> _save() async {
    final repository = ref.read(workoutRepositoryProvider);
    if (repository is! WorkoutCustomizationRepository) return;
    setState(() => _saving = true);
    final result = await (repository as WorkoutCustomizationRepository)
        .customizeExercises(widget.workoutId, _ids!);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        ref.invalidate(workoutByIdProvider(widget.workoutId));
        ref.invalidate(workoutSchedulerProvider);
        ref.invalidate(dashboard.dashboardProvider);
        ref.invalidate(progress.progressProvider);
        Navigator.pop(context);
      case Failure(error: final error):
        final message = error is NetworkError
            ? 'Workout customization requires a connection. Your existing workout was not changed.'
            : error is ValidationError && error.fieldErrors.isNotEmpty
                ? error.fieldErrors.values.first
                : error.message;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
