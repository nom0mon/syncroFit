import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/providers.dart';
import '../../../shared/models/models.dart';
import 'workout_scheduler_provider.dart';

/// The lifecycle status of the workout generator flow.
enum WorkoutGeneratorStatus { idle, generating, generated, error }

/// Immutable state for the workout generator.
///
/// Tracks the current [status], any [generatedWorkouts] produced by the last
/// successful generation, the user's include/exclude exercise selections, and
/// an optional [errorMessage] when generation fails.
class WorkoutGeneratorState {
  final WorkoutGeneratorStatus status;
  final List<Workout> generatedWorkouts;
  final Set<int> includedExerciseIds;
  final Set<int> excludedExerciseIds;
  final String? errorMessage;

  const WorkoutGeneratorState({
    this.status = WorkoutGeneratorStatus.idle,
    this.generatedWorkouts = const [],
    this.includedExerciseIds = const {},
    this.excludedExerciseIds = const {},
    this.errorMessage,
  });

  WorkoutGeneratorState copyWith({
    WorkoutGeneratorStatus? status,
    List<Workout>? generatedWorkouts,
    Set<int>? includedExerciseIds,
    Set<int>? excludedExerciseIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WorkoutGeneratorState(
      status: status ?? this.status,
      generatedWorkouts: generatedWorkouts ?? this.generatedWorkouts,
      includedExerciseIds: includedExerciseIds ?? this.includedExerciseIds,
      excludedExerciseIds: excludedExerciseIds ?? this.excludedExerciseIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// State machine that drives the explicit workout generation flow.
///
/// CRITICAL: generation is *only* triggered via [generate]. Nothing is
/// generated in the constructor, on profile load, or on navigation. The
/// notifier starts in [WorkoutGeneratorStatus.idle] with no workouts.
///
/// Include/exclude selections are mutually exclusive per exercise: adding an
/// exercise to one set removes it from the other.
class WorkoutGeneratorNotifier extends StateNotifier<WorkoutGeneratorState> {
  final Ref _ref;

  WorkoutGeneratorNotifier(this._ref)
      : super(const WorkoutGeneratorState());

  /// Toggles an exercise in the included set.
  ///
  /// If the exercise is being added, it is also removed from the excluded set
  /// (an exercise cannot be both preferred and excluded).
  void toggleIncluded(int exerciseId) {
    final included = Set<int>.from(state.includedExerciseIds);
    final excluded = Set<int>.from(state.excludedExerciseIds);

    if (included.contains(exerciseId)) {
      included.remove(exerciseId);
    } else {
      included.add(exerciseId);
      excluded.remove(exerciseId);
    }

    state = state.copyWith(
      includedExerciseIds: included,
      excludedExerciseIds: excluded,
    );
  }

  /// Toggles an exercise in the excluded set.
  ///
  /// If the exercise is being added, it is also removed from the included set
  /// (an exercise cannot be both excluded and preferred).
  void toggleExcluded(int exerciseId) {
    final included = Set<int>.from(state.includedExerciseIds);
    final excluded = Set<int>.from(state.excludedExerciseIds);

    if (excluded.contains(exerciseId)) {
      excluded.remove(exerciseId);
    } else {
      excluded.add(exerciseId);
      included.remove(exerciseId);
    }

    state = state.copyWith(
      includedExerciseIds: included,
      excludedExerciseIds: excluded,
    );
  }

  /// Explicitly generates workouts using the current include/exclude
  /// selections. This is the only path that triggers generation.
  ///
  /// On success, refreshes the workout scheduler so the new plan appears in
  /// the schedule-aware views.
  Future<void> generate() async {
    state = state.copyWith(
      status: WorkoutGeneratorStatus.generating,
      clearError: true,
    );

    final result =
        await _ref.read(remoteWorkoutRepositoryProvider).generateRecommendation(
              includedExercises: [...state.includedExerciseIds],
              excludedExercises: [...state.excludedExerciseIds],
            );

    switch (result) {
      case Success(value: final workouts):
        state = state.copyWith(
          status: WorkoutGeneratorStatus.generated,
          generatedWorkouts: workouts,
          clearError: true,
        );
        // Refresh the schedule-aware view with the freshly generated plan.
        _ref.read(workoutSchedulerProvider.notifier).refresh();
      case Failure(error: final error):
        state = state.copyWith(
          status: WorkoutGeneratorStatus.error,
          errorMessage: error.message,
        );
    }
  }

  /// Resets the generator back to its initial idle state.
  void reset() {
    state = const WorkoutGeneratorState();
  }
}

/// Provider exposing the [WorkoutGeneratorNotifier] and its state.
final workoutGeneratorProvider =
    StateNotifierProvider<WorkoutGeneratorNotifier, WorkoutGeneratorState>(
  (ref) => WorkoutGeneratorNotifier(ref),
);
