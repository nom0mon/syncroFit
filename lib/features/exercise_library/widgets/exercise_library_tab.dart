import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/exercise.dart';
import '../../../shared/widgets/edge_fade_gradient.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/exercise_provider.dart';
import 'exercise_row.dart';

/// A tab widget containing the exercise library with search and filter controls.
///
/// Extracted from [ExerciseListScreen] for use inside a [TabBarView].
/// Uses [AutomaticKeepAliveClientMixin] to preserve scroll position and state
/// across tab switches.
///
/// Validates: Requirements 8.2, 8.5
class ExerciseLibraryTab extends ConsumerStatefulWidget {
  const ExerciseLibraryTab({super.key});

  @override
  ConsumerState<ExerciseLibraryTab> createState() => _ExerciseLibraryTabState();
}

class _ExerciseLibraryTabState extends ConsumerState<ExerciseLibraryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Forces a refresh by calling refreshCaches with forceRefresh: true,
  /// which invalidates cache metadata and forces a backend fetch regardless
  /// of cache age, then reloads the exercise list.
  ///
  /// Validates: Requirements 11.3, 11.4
  Future<void> _onRefresh() async {
    final syncEngine = ref.read(syncEngineProvider);
    await syncEngine.refreshCaches(forceRefresh: true);
    await ref.read(exerciseProvider.notifier).loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(exerciseProvider);

    if (state.isLoading) {
      return const LoadingIndicator();
    }

    if (state.errorMessage != null) {
      return ErrorDisplay(
        message: state.errorMessage!,
        onRetry: () => ref.read(exerciseProvider.notifier).loadExercises(),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Column(
        children: [
          _SearchBar(searchQuery: state.searchQuery),
          _FilterControls(
            allExercises: state.allExercises,
            selectedMuscleGroups: state.selectedMuscleGroups,
            selectedDifficulty: state.selectedDifficulty,
          ),
          Expanded(
            child: state.filteredExercises.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EmptyState(
                        icon: Icons.search_off,
                        message: 'No exercises found matching your filters',
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      _ExerciseListView(exercises: state.filteredExercises),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: EdgeFadeGradient(isTop: true),
                      ),
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: EdgeFadeGradient(isTop: false),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Search input with case-insensitive substring matching.
class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({required this.searchQuery});

  final String searchQuery;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search exercises...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    ref.read(exerciseProvider.notifier).setSearchQuery('');
                  },
                )
              : null,
        ),
        onChanged: (value) {
          ref.read(exerciseProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }
}

/// Filter controls: muscle group chips (multi-select) and difficulty chips.
class _FilterControls extends ConsumerWidget {
  const _FilterControls({
    required this.allExercises,
    required this.selectedMuscleGroups,
    required this.selectedDifficulty,
  });

  final List<Exercise> allExercises;
  final Set<String> selectedMuscleGroups;
  final DifficultyLevel? selectedDifficulty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muscleGroups = allExercises.map((e) => e.muscleGroup).toSet().toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Muscle group filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: muscleGroups.map((group) {
                final isSelected = selectedMuscleGroups.contains(group);
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(group),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                          .read(exerciseProvider.notifier)
                          .toggleMuscleGroupFilter(group);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Difficulty filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DifficultyLevel.values.map((level) {
                final isSelected = selectedDifficulty == level;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(_difficultyLabel(level)),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                          .read(exerciseProvider.notifier)
                          .setDifficultyFilter(isSelected ? null : level);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Scrollable list of exercise items.
class _ExerciseListView extends StatelessWidget {
  const _ExerciseListView({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
      ),
      itemCount: exercises.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        return ExerciseRow(exercise: exercises[index]);
      },
    );
  }
}

/// Returns a user-friendly label for a difficulty level.
String _difficultyLabel(DifficultyLevel level) {
  return switch (level) {
    DifficultyLevel.beginner => 'Beginner',
    DifficultyLevel.intermediate => 'Intermediate',
    DifficultyLevel.advanced => 'Advanced',
  };
}
