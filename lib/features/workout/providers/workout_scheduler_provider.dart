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

  /// Maps a list of workouts to their assigned days, producing one
  /// [ScheduledWorkout] per workout.
  ///
  /// The workout's own `dayOfWeek` field (set by the backend recommendation
  /// engine to match the user's selected availability days) is the source of
  /// truth for scheduling. A workout is only scheduled on a day the user
  /// actually selected — if a workout carries a day that is not in
  /// [availabilityDays], it is skipped (defensive guard for Issue 1: date
  /// accuracy).
  ///
  /// If a workout has no parseable day (e.g. user-created without a day),
  /// it falls back to assigning the next unused availability day in order.
  List<ScheduledWorkout> _mapWorkoutsToSchedule(
    List<Workout> workouts,
    List<DayOfWeek> availabilityDays,
  ) {
    final today = _currentDayOfWeek();
    final availabilitySet = availabilityDays.toSet();
    final scheduled = <ScheduledWorkout>[];
    final usedDays = <DayOfWeek>{};

    // Availability days sorted Monday→Sunday for deterministic fallback.
    final sortedAvailability = [...availabilityDays]
      ..sort((a, b) => a.index.compareTo(b.index));

    for (final workout in workouts) {
      final day = _parseWorkoutDay(workout.dayOfWeek);

      DayOfWeek? assignedDay;
      if (day != null && availabilitySet.contains(day)) {
        // Use the backend-assigned day (matches a selected available day).
        assignedDay = day;
      } else {
        // Fallback: assign the next unused availability day in order.
        assignedDay = sortedAvailability
            .cast<DayOfWeek?>()
            .firstWhere((d) => !usedDays.contains(d), orElse: () => null);
      }

      if (assignedDay == null) {
        // No valid day available for this workout — skip it rather than
        // showing it on a day the user did not select.
        continue;
      }

      usedDays.add(assignedDay);
      scheduled.add(
        ScheduledWorkout(
          workoutId: workout.id,
          workoutName: workout.name,
          dayOfWeek: assignedDay,
          estimatedDurationMinutes: workout.estimatedDurationMinutes,
          isCompleted: _isDayCompleted(assignedDay, today),
          isGenerated: workout.isGenerated,
        ),
      );
    }

    return scheduled;
  }

  /// Parses a workout's `dayOfWeek` string (e.g. "3" for Wednesday, or a day
  /// name) into a [DayOfWeek] enum. Returns null if it cannot be parsed.
  DayOfWeek? _parseWorkoutDay(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    // Numeric form: "1" = Monday ... "7" = Sunday.
    final asNumber = int.tryParse(raw.trim());
    if (asNumber != null && asNumber >= 1 && asNumber <= 7) {
      return DayOfWeek.values[asNumber - 1];
    }

    // Name form: "monday", "Tuesday", etc.
    final lower = raw.trim().toLowerCase();
    for (final day in DayOfWeek.values) {
      if (day.name.toLowerCase() == lower) return day;
    }
    return null;
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
