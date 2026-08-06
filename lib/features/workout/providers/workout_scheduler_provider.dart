import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/workout_repository.dart';
import '../../../features/profile/providers/profile_provider.dart';
import '../../../shared/models/models.dart';
import 'workout_provider.dart';

/// The state for the workout scheduler, containing the list of scheduled
/// workouts plus loading/error indicators.
class WorkoutSchedulerState {
  /// The scheduled workouts mapped to the user's availability days.
  final List<ScheduledWorkout> scheduledWorkouts;

  /// Whether the scheduler is currently loading data.
  final bool isLoading;

  /// An optional error message if loading failed.
  final String? errorMessage;

  const WorkoutSchedulerState({
    this.scheduledWorkouts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  WorkoutSchedulerState copyWith({
    List<ScheduledWorkout>? scheduledWorkouts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return WorkoutSchedulerState(
      scheduledWorkouts: scheduledWorkouts ?? this.scheduledWorkouts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Maps the user's workout recommendations to their availability days,
/// producing a [List<ScheduledWorkout>] with completion status for each day.
///
/// Watches both the workout repository (for recommendations) and the profile
/// provider (for availability_days).
///
/// Validates: Requirements 9.1, 9.2, 9.3
class WorkoutSchedulerNotifier extends StateNotifier<WorkoutSchedulerState> {
  final Ref _ref;

  WorkoutSchedulerNotifier(this._ref) : super(const WorkoutSchedulerState()) {
    _loadSchedule();
  }

  WorkoutRepository get _workoutRepository =>
      _ref.read(workoutRepositoryProvider);

  /// Loads the workout schedule by combining recommendations with
  /// the user's availability days.
  Future<void> _loadSchedule() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Get user profile for availability days
      final profileAsync = _ref.read(profileProvider);
      final profile = profileAsync.valueOrNull;

      if (profile == null) {
        // No profile available — can't build schedule
        state = const WorkoutSchedulerState();
        return;
      }

      final availabilityDays = profile.workoutAvailability;
      if (availabilityDays.isEmpty) {
        // No availability days set — empty schedule
        state = const WorkoutSchedulerState();
        return;
      }

      // Fetch workouts/recommendations
      final result = await _workoutRepository.getAll();

      switch (result) {
        case Success(value: final workouts):
          if (workouts.isEmpty) {
            // No recommendations exist — empty state
            state = const WorkoutSchedulerState();
            return;
          }

          final scheduled = _mapWorkoutsToSchedule(workouts, availabilityDays);
          state = WorkoutSchedulerState(scheduledWorkouts: scheduled);

        case Failure(error: final error):
          state = WorkoutSchedulerState(
            errorMessage: error.toString(),
          );
      }
    } catch (e) {
      state = WorkoutSchedulerState(errorMessage: e.toString());
    }
  }

  /// Reloads the schedule from the repositories.
  Future<void> refresh() async {
    await _loadSchedule();
  }

  /// Maps a list of workouts to the user's availability days, producing
  /// one [ScheduledWorkout] per availability day.
  ///
  /// Workouts are assigned in order to the availability days. If there are
  /// more availability days than workouts, the extra days are skipped.
  /// If there are more workouts than availability days, the extra workouts
  /// are not scheduled.
  List<ScheduledWorkout> _mapWorkoutsToSchedule(
    List<Workout> workouts,
    List<DayOfWeek> availabilityDays,
  ) {
    final today = _currentDayOfWeek();
    final scheduled = <ScheduledWorkout>[];

    // Assign workouts to availability days in order.
    // The number of scheduled workouts is the minimum of available workouts
    // and availability days.
    final count =
        workouts.length < availabilityDays.length
            ? workouts.length
            : availabilityDays.length;

    for (var i = 0; i < count; i++) {
      final workout = workouts[i];
      final day = availabilityDays[i];
      final isCompleted = _isDayCompleted(day, today);

      scheduled.add(
        ScheduledWorkout(
          workoutId: workout.id,
          workoutName: workout.name,
          dayOfWeek: day,
          estimatedDurationMinutes: workout.estimatedDurationMinutes,
          isCompleted: isCompleted,
        ),
      );
    }

    return scheduled;
  }

  /// Determines whether a given day should be marked as completed.
  ///
  /// A day is considered completed if it comes before today in the week.
  /// Today is considered active (not completed), and future days are upcoming.
  bool _isDayCompleted(DayOfWeek day, DayOfWeek today) {
    return day.index < today.index;
  }

  /// Returns the current day of the week as a [DayOfWeek] enum value.
  DayOfWeek _currentDayOfWeek() {
    final weekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    return DayOfWeek.values[weekday - 1];
  }
}

/// Provider for the [WorkoutSchedulerNotifier] that manages the weekly
/// workout schedule state.
///
/// This provider watches the profile for availability_days changes and
/// the workout repository for recommendation changes. It auto-disposes
/// when no longer listened to.
final workoutSchedulerProvider = StateNotifierProvider.autoDispose<
    WorkoutSchedulerNotifier, WorkoutSchedulerState>(
  (ref) {
    // Watch profile changes to rebuild schedule when availability changes
    ref.watch(profileProvider);
    return WorkoutSchedulerNotifier(ref);
  },
);

/// Convenience provider that exposes just the list of scheduled workouts.
final scheduledWorkoutsProvider = Provider.autoDispose<List<ScheduledWorkout>>((
  ref,
) {
  return ref.watch(workoutSchedulerProvider).scheduledWorkouts;
});

/// Convenience provider for today's scheduled workout (if any).
final todaysScheduledWorkoutProvider =
    Provider.autoDispose<ScheduledWorkout?>((ref) {
  final schedule = ref.watch(workoutSchedulerProvider).scheduledWorkouts;
  final today = DayOfWeek.values[DateTime.now().weekday - 1];

  for (final workout in schedule) {
    if (workout.dayOfWeek == today) {
      return workout;
    }
  }
  return null;
});

/// Determines the visual status of a scheduled workout day.
enum WorkoutDayStatus {
  /// Day is before today — considered completed.
  completed,

  /// Day is today — the active workout.
  active,

  /// Day is after today — upcoming.
  upcoming,
}

/// Returns the visual status for a given [ScheduledWorkout] relative to today.
WorkoutDayStatus getWorkoutDayStatus(ScheduledWorkout workout) {
  final todayIndex = DateTime.now().weekday - 1; // 0 = Monday, 6 = Sunday
  final dayIndex = workout.dayOfWeek.index;

  if (workout.isCompleted || dayIndex < todayIndex) {
    return WorkoutDayStatus.completed;
  } else if (dayIndex == todayIndex) {
    return WorkoutDayStatus.active;
  } else {
    return WorkoutDayStatus.upcoming;
  }
}
