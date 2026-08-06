import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/caching/caching_providers.dart';
import '../../../data/repositories/exercise_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [ExerciseRepository] implementation.
///
/// Uses [CachingExerciseRepository] which wraps the remote repository with
/// local SQLite caching and offline support. The provider can be overridden
/// with a mock in tests via ProviderScope overrides.
final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ref.watch(cachingExerciseRepositoryProvider);
});

/// Provides the current exercise library state managed by [ExerciseNotifier].
final exerciseProvider =
    StateNotifierProvider<ExerciseNotifier, ExerciseState>((ref) {
  return ExerciseNotifier(ref);
});

/// Holds the current state of the exercise library including exercises,
/// active filters, and search query.
class ExerciseState {
  final List<Exercise> allExercises;
  final List<Exercise> filteredExercises;
  final Set<String> selectedMuscleGroups;
  final DifficultyLevel? selectedDifficulty;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const ExerciseState({
    this.allExercises = const [],
    this.filteredExercises = const [],
    this.selectedMuscleGroups = const {},
    this.selectedDifficulty,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  ExerciseState copyWith({
    List<Exercise>? allExercises,
    List<Exercise>? filteredExercises,
    Set<String>? selectedMuscleGroups,
    DifficultyLevel? selectedDifficulty,
    bool clearDifficulty = false,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExerciseState(
      allExercises: allExercises ?? this.allExercises,
      filteredExercises: filteredExercises ?? this.filteredExercises,
      selectedMuscleGroups: selectedMuscleGroups ?? this.selectedMuscleGroups,
      selectedDifficulty: clearDifficulty
          ? null
          : (selectedDifficulty ?? this.selectedDifficulty),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Manages exercise library state including loading, filtering, and searching.
class ExerciseNotifier extends StateNotifier<ExerciseState> {
  ExerciseNotifier(this._ref) : super(const ExerciseState()) {
    loadExercises();
  }

  final Ref _ref;

  ExerciseRepository get _repository => _ref.read(exerciseRepositoryProvider);

  /// Loads all exercises from the repository.
  Future<void> loadExercises() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.getAll();

    switch (result) {
      case Success(value: final exercises):
        state = state.copyWith(
          allExercises: exercises,
          filteredExercises: exercises,
          isLoading: false,
        );
      case Failure(error: final error):
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        );
    }
  }

  /// Sets the search query and re-applies all filters.
  ///
  /// Search is case-insensitive substring matching on exercise name.
  /// Results update immediately on input change (Req 8.3).
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  /// Toggles a muscle group in the active filter set.
  ///
  /// If the group is already selected, it is removed. If not, it is added.
  /// Supports multiple muscle groups selected simultaneously (Req 8.2).
  void toggleMuscleGroupFilter(String muscleGroup) {
    final updatedGroups = Set<String>.from(state.selectedMuscleGroups);
    if (updatedGroups.contains(muscleGroup)) {
      updatedGroups.remove(muscleGroup);
    } else {
      updatedGroups.add(muscleGroup);
    }
    state = state.copyWith(selectedMuscleGroups: updatedGroups);
    _applyFilters();
  }

  /// Sets the difficulty level filter.
  ///
  /// Pass `null` to clear the difficulty filter.
  void setDifficultyFilter(DifficultyLevel? difficulty) {
    if (difficulty == null) {
      state = state.copyWith(clearDifficulty: true);
    } else {
      state = state.copyWith(selectedDifficulty: difficulty);
    }
    _applyFilters();
  }

  /// Clears all active filters and search query, showing all exercises.
  void clearFilters() {
    state = state.copyWith(
      selectedMuscleGroups: {},
      clearDifficulty: true,
      searchQuery: '',
      filteredExercises: state.allExercises,
    );
  }

  /// Applies all active criteria (muscle groups OR match + difficulty match +
  /// name search) to produce the filtered exercise list.
  ///
  /// Combined filtering logic:
  /// - Muscle groups: exercise matches if its muscleGroup is in the selected set
  ///   (OR logic among selected groups). If no groups selected, all pass.
  /// - Difficulty: exercise matches if its difficulty equals the selected level.
  ///   If no difficulty selected, all pass.
  /// - Search: exercise matches if its name contains the query as a
  ///   case-insensitive substring. If query is empty, all pass.
  void _applyFilters() {
    final query = state.searchQuery.toLowerCase();
    final muscleGroups = state.selectedMuscleGroups;
    final difficulty = state.selectedDifficulty;

    final filtered = state.allExercises.where((exercise) {
      // Search filter: case-insensitive substring match on name
      if (query.isNotEmpty && !exercise.name.toLowerCase().contains(query)) {
        return false;
      }

      // Muscle group filter: OR match among selected groups
      if (muscleGroups.isNotEmpty &&
          !muscleGroups.contains(exercise.muscleGroup)) {
        return false;
      }

      // Difficulty filter: exact match
      if (difficulty != null && exercise.difficulty != difficulty) {
        return false;
      }

      return true;
    }).toList();

    state = state.copyWith(filteredExercises: filtered);
  }
}
