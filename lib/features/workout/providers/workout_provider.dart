import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/caching/caching_providers.dart';
import '../../../data/repositories/workout_history_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [WorkoutRepository] implementation.
///
/// Uses [CachingWorkoutRepository] which wraps the remote repository with
/// local SQLite caching and offline support. The provider can be overridden
/// with a mock in tests via ProviderScope overrides.
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return ref.watch(cachingWorkoutRepositoryProvider);
});

/// Provides the [WorkoutHistoryRepository] for saving completed sessions.
final workoutHistoryRepositoryProvider =
    Provider<WorkoutHistoryRepository>((ref) {
  return ref.watch(cachingWorkoutHistoryRepositoryProvider);
});

/// State representing the current workout session in progress.
class WorkoutSessionState {
  /// The workout being performed.
  final Workout? workout;

  /// Index of the current exercise in [workout.exercises].
  final int currentExerciseIndex;

  /// List of exercises that have been completed in this session.
  final List<CompletedExercise> completedExercises;

  /// Whether the workout session is actively in progress.
  final bool isInProgress;

  /// Whether the workout session has been completed (all exercises done).
  final bool isCompleted;

  /// The timestamp when the workout was started.
  final DateTime? startedAt;

  /// The timestamp when the workout was completed.
  final DateTime? completedAt;

  /// Whether we are currently in a rest period between exercises.
  final bool isResting;

  const WorkoutSessionState({
    this.workout,
    this.currentExerciseIndex = 0,
    this.completedExercises = const [],
    this.isInProgress = false,
    this.isCompleted = false,
    this.startedAt,
    this.completedAt,
    this.isResting = false,
  });

  /// The current exercise being performed, or null if no workout is loaded.
  WorkoutExercise? get currentExercise {
    if (workout == null) return null;
    if (currentExerciseIndex >= workout!.exercises.length) return null;
    return workout!.exercises[currentExerciseIndex];
  }

  /// Whether the current exercise is the last one in the workout.
  bool get isLastExercise {
    if (workout == null) return true;
    return currentExerciseIndex >= workout!.exercises.length - 1;
  }

  /// Total number of exercises in the workout.
  int get totalExercises => workout?.exercises.length ?? 0;

  /// The number of exercises completed so far.
  int get exercisesCompletedCount => completedExercises.length;

  /// Total duration in seconds from start to completion (or now if still in progress).
  int get totalDurationSeconds {
    if (startedAt == null) return 0;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!).inSeconds;
  }

  /// Rest seconds between exercises (default 30, range 10-120).
  int get currentRestSeconds {
    // The simplified WorkoutExercise no longer stores restSeconds;
    // use a fixed default rest period.
    const rest = 30;
    return rest.clamp(10, 120);
  }

  WorkoutSessionState copyWith({
    Workout? workout,
    int? currentExerciseIndex,
    List<CompletedExercise>? completedExercises,
    bool? isInProgress,
    bool? isCompleted,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? isResting,
  }) {
    return WorkoutSessionState(
      workout: workout ?? this.workout,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      completedExercises: completedExercises ?? this.completedExercises,
      isInProgress: isInProgress ?? this.isInProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      isResting: isResting ?? this.isResting,
    );
  }
}

/// Manages the active workout session state including exercise progression,
/// completion tracking, and rest periods.
///
/// Validates: Requirements 7.2, 7.3, 7.4, 7.10
class WorkoutNotifier extends StateNotifier<WorkoutSessionState> {
  WorkoutNotifier(this._ref) : super(const WorkoutSessionState());

  final Ref _ref;

  WorkoutRepository get _repository => _ref.read(workoutRepositoryProvider);
  WorkoutHistoryRepository get _historyRepo =>
      _ref.read(workoutHistoryRepositoryProvider);

  /// Loads a workout by its [workoutId] from the repository.
  ///
  /// Does not start the session — call [startWorkout] after loading.
  Future<bool> loadWorkout(String workoutId) async {
    final result = await _repository.getById(workoutId);
    switch (result) {
      case Success(value: final workout):
        state = WorkoutSessionState(workout: workout);
        return true;
      case Failure():
        return false;
    }
  }

  /// Starts the workout session, marking it as in progress.
  void startWorkout() {
    if (state.workout == null) return;
    state = state.copyWith(
      isInProgress: true,
      startedAt: DateTime.now(),
      currentExerciseIndex: 0,
      completedExercises: [],
      isCompleted: false,
      isResting: false,
    );
  }

  /// Marks the current exercise as completed and begins the rest period
  /// (unless it's the last exercise, in which case the workout completes).
  void completeCurrentExercise() {
    final exercise = state.currentExercise;
    if (exercise == null) return;

    final completed = CompletedExercise(
      exerciseId: exercise.exerciseId.toString(),
      exerciseName: 'Exercise ${exercise.exerciseId}',
      setsCompleted: exercise.sets,
      repsOrDuration: exercise.durationSeconds > 0
          ? exercise.durationSeconds
          : exercise.reps,
    );

    final updatedCompleted = [...state.completedExercises, completed];

    if (state.isLastExercise) {
      // Last exercise completed — finish the workout
      state = state.copyWith(
        completedExercises: updatedCompleted,
        isInProgress: false,
        isCompleted: true,
        completedAt: DateTime.now(),
        isResting: false,
      );
    } else {
      // Move to rest period before next exercise
      state = state.copyWith(
        completedExercises: updatedCompleted,
        isResting: true,
      );
    }
  }

  /// Advances to the next exercise in the workout, ending the rest period.
  void advanceToNextExercise() {
    if (state.isLastExercise) return;
    state = state.copyWith(
      currentExerciseIndex: state.currentExerciseIndex + 1,
      isResting: false,
    );
  }

  /// Skips the current exercise without completing it and advances.
  ///
  /// If it's the last exercise, completes the workout.
  void skipCurrentExercise() {
    if (state.isLastExercise) {
      state = state.copyWith(
        isInProgress: false,
        isCompleted: true,
        completedAt: DateTime.now(),
        isResting: false,
      );
    } else {
      state = state.copyWith(
        currentExerciseIndex: state.currentExerciseIndex + 1,
        isResting: false,
      );
    }
  }

  /// Skips the rest period and immediately advances to the next exercise.
  void skipRest() {
    if (!state.isResting) return;
    advanceToNextExercise();
  }

  /// Builds and saves a [WorkoutHistory] from the current completed state.
  ///
  /// Returns the saved record or null if the workout wasn't completed.
  Future<WorkoutHistory?> saveCompletedSession() async {
    if (!state.isCompleted || state.workout == null) return null;

    final record = WorkoutHistory(
      id: 'history-${DateTime.now().millisecondsSinceEpoch}',
      userId: '', // Will be set by backend
      workoutName: state.workout!.name,
      completedAt: state.completedAt ?? DateTime.now(),
      totalDurationSeconds: state.totalDurationSeconds,
      exercisesCompleted: state.completedExercises
          .map((e) => e.toJson())
          .toList(),
    );

    final result = await _historyRepo.save(record);
    switch (result) {
      case Success(value: final saved):
        return saved;
      case Failure():
        return null;
    }
  }

  /// Resets the workout session state completely.
  void resetSession() {
    state = const WorkoutSessionState();
  }
}

/// Provider for the [WorkoutNotifier] managing the active workout session.
final workoutProvider =
    StateNotifierProvider.autoDispose<WorkoutNotifier, WorkoutSessionState>(
  (ref) => WorkoutNotifier(ref),
);

/// Provider that fetches a workout by ID (for the detail screen).
final workoutByIdProvider =
    FutureProvider.autoDispose.family<Workout?, String>((ref, id) async {
  final repository = ref.read(workoutRepositoryProvider);
  final result = await repository.getById(id);
  switch (result) {
    case Success(value: final workout):
      return workout;
    case Failure():
      return null;
  }
});
