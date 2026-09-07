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
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/exercise_provider.dart';
import 'exercise_row.dart';

/// A tab containing the responsive exercise library search, filters, and
/// adaptive list/grid.
class ExerciseLibraryTab extends ConsumerStatefulWidget {
  const ExerciseLibraryTab({
    super.key,
    this.showStatusStates = true,
  });

  /// Whether this tab owns loading and error presentation.
  ///
  /// The standalone exercise-list screen handles those states above this
  /// widget, while the released tab uses the default value.
  final bool showStatusStates;

  @override
  ConsumerState<ExerciseLibraryTab> createState() => _ExerciseLibraryTabState();
}

class _ExerciseLibraryTabState extends ConsumerState<ExerciseLibraryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _onRefresh() async {
    final syncEngine = ref.read(syncEngineProvider);
    await syncEngine.refreshCaches(forceRefresh: true);
    await ref.read(exerciseProvider.notifier).loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(exerciseProvider);

    if (widget.showStatusStates && state.isLoading) {
      return const LoadingIndicator();
    }

    if (widget.showStatusStates && state.errorMessage != null) {
      return ErrorDisplay(
        message: state.errorMessage!,
        onRetry: () => ref.read(exerciseProvider.notifier).loadExercises(),
      );
    }

    return SafeArea(
      top: false,
      child: ResponsiveConstrainedPage(
        child: RefreshIndicator(
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
                          _ExerciseResults(
                            exercises: state.filteredExercises,
                          ),
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
        ),
      ),
    );
  }
}

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
        0,
        AppSpacing.md,
        0,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search exercises...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear exercise search',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    ref.read(exerciseProvider.notifier).setSearchQuery('');
                  },
                )
              : null,
        ),
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          ref.read(exerciseProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }
}

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

    final muscleChips = muscleGroups.map((group) {
      final isSelected = selectedMuscleGroups.contains(group);
      return FilterChip(
        label: Text(
          allExercises
              .firstWhere((exercise) => exercise.muscleGroup == group)
              .displayMuscleGroup,
          overflow: TextOverflow.ellipsis,
        ),
        selected: isSelected,
        onSelected: (_) {
          ref.read(exerciseProvider.notifier).toggleMuscleGroupFilter(group);
        },
      );
    }).toList();

    final difficultyChips = DifficultyLevel.values.map((level) {
      final isSelected = selectedDifficulty == level;
      return ChoiceChip(
        label: Text(_difficultyLabel(level)),
        selected: isSelected,
        onSelected: (_) {
          ref
              .read(exerciseProvider.notifier)
              .setDifficultyFilter(isSelected ? null : level);
        },
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthClass =
            ResponsiveStandards.widthClassFor(constraints.maxWidth);
        final wrapsFilters = widthClass == AppWidthClass.tablet ||
            widthClass == AppWidthClass.large;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdaptiveChipGroup(
              chips: muscleChips,
              wraps: wrapsFilters,
            ),
            const SizedBox(height: AppSpacing.sm),
            _AdaptiveChipGroup(
              chips: difficultyChips,
              wraps: wrapsFilters,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        );
      },
    );
  }
}

class _AdaptiveChipGroup extends StatelessWidget {
  const _AdaptiveChipGroup({
    required this.chips,
    required this.wraps,
  });

  final List<Widget> chips;
  final bool wraps;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    if (wraps) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: chips,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < chips.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            chips[index],
          ],
        ],
      ),
    );
  }
}

class _ExerciseResults extends StatelessWidget {
  const _ExerciseResults({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: AdaptiveGridList(
        minItemWidth: 320,
        maxColumns: 2,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          for (final exercise in exercises) ExerciseRow(exercise: exercise),
        ],
      ),
    );
  }
}

String _difficultyLabel(DifficultyLevel level) {
  return switch (level) {
    DifficultyLevel.beginner => 'Beginner',
    DifficultyLevel.intermediate => 'Intermediate',
    DifficultyLevel.advanced => 'Advanced',
  };
}
