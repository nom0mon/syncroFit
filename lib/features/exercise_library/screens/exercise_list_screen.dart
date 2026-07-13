import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/exercise.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/exercise_provider.dart';

/// Displays a browsable list of exercises with search and filter controls.
///
/// Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.6, 8.7
class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
      ),
      body: state.isLoading
          ? const LoadingIndicator()
          : state.errorMessage != null
              ? ErrorDisplay(
                  message: state.errorMessage!,
                  onRetry: () =>
                      ref.read(exerciseProvider.notifier).loadExercises(),
                )
              : const _ExerciseListContent(),
    );
  }
}

class _ExerciseListContent extends ConsumerWidget {
  const _ExerciseListContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseProvider);

    return Column(
      children: [
        _SearchBar(searchQuery: state.searchQuery),
        _FilterControls(
          allExercises: state.allExercises,
          selectedMuscleGroups: state.selectedMuscleGroups,
          selectedDifficulty: state.selectedDifficulty,
        ),
        Expanded(
          child: state.filteredExercises.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  message: 'No exercises found matching your filters',
                )
              : _ExerciseListView(exercises: state.filteredExercises),
        ),
      ],
    );
  }
}

/// Search input with case-insensitive substring matching (Req 8.3).
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
    // Only update controller text if the search query was cleared externally
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

/// Filter controls: muscle group chips (multi-select) and difficulty chips (Req 8.2).
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
    final muscleGroups = allExercises
        .map((e) => e.muscleGroup)
        .toSet()
        .toList()
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

/// Scrollable list of exercise items (Req 8.1).
class _ExerciseListView extends StatelessWidget {
  const _ExerciseListView({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: exercises.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return _ExerciseListItem(exercise: exercises[index]);
      },
    );
  }
}

/// Individual exercise list item showing name, muscle group, difficulty,
/// and image placeholder (Req 8.1). Tappable to navigate to detail (Req 8.4).
class _ExerciseListItem extends StatelessWidget {
  const _ExerciseListItem({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () {
          context.go('/exercises/${exercise.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Image placeholder
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Exercise info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      exercise.muscleGroup,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Difficulty badge
              _DifficultyBadge(difficulty: exercise.difficulty),
            ],
          ),
        ),
      ),
    );
  }
}

/// A colored badge indicating exercise difficulty level.
class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty});

  final DifficultyLevel difficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _difficultyColor(difficulty);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _difficultyLabel(difficulty),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
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

/// Returns a color associated with a difficulty level.
Color _difficultyColor(DifficultyLevel level) {
  return switch (level) {
    DifficultyLevel.beginner => AppColors.successGreen,
    DifficultyLevel.intermediate => AppColors.warningOrange,
    DifficultyLevel.advanced => AppColors.errorRed,
  };
}
