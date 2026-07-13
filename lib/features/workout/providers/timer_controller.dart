import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/enums.dart';

/// State for the timer controller, tracking remaining seconds and timer state.
class TimerControllerState {
  final int remainingSeconds;
  final TimerState state;

  const TimerControllerState({
    this.remainingSeconds = 0,
    this.state = TimerState.idle,
  });

  TimerControllerState copyWith({
    int? remainingSeconds,
    TimerState? state,
  }) {
    return TimerControllerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      state: state ?? this.state,
    );
  }
}

/// Manages countdown timer logic using [Timer.periodic] with 1-second intervals.
///
/// Operates entirely in the UI layer without backend communication.
/// Supports start, pause, resume, reset, and skip operations.
///
/// Validates: Requirements 7.2, 7.3, 7.4, 7.10
class TimerController extends StateNotifier<TimerControllerState> {
  TimerController() : super(const TimerControllerState());

  Timer? _timer;
  int _totalDuration = 0;

  /// The total duration that was set when [start] was called.
  int get totalDuration => _totalDuration;

  /// Starts the countdown from [durationSeconds].
  ///
  /// If a timer is already running, it is cancelled and restarted.
  void start(int durationSeconds) {
    _cancelTimer();
    _totalDuration = durationSeconds;
    state = TimerControllerState(
      remainingSeconds: durationSeconds,
      state: TimerState.running,
    );
    _startPeriodicTimer();
  }

  /// Pauses the countdown. The timer can be resumed later.
  void pause() {
    if (state.state != TimerState.running) return;
    _cancelTimer();
    state = state.copyWith(state: TimerState.paused);
  }

  /// Resumes the countdown from the current remaining seconds.
  void resume() {
    if (state.state != TimerState.paused) return;
    state = state.copyWith(state: TimerState.running);
    _startPeriodicTimer();
  }

  /// Resets the timer to idle state with zero remaining.
  void reset() {
    _cancelTimer();
    _totalDuration = 0;
    state = const TimerControllerState();
  }

  /// Skips the current countdown, immediately setting state to completed.
  void skip() {
    _cancelTimer();
    state = state.copyWith(
      remainingSeconds: 0,
      state: TimerState.completed,
    );
  }

  void _startPeriodicTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final newRemaining = state.remainingSeconds - 1;
      if (newRemaining <= 0) {
        _cancelTimer();
        state = state.copyWith(
          remainingSeconds: 0,
          state: TimerState.completed,
        );
      } else {
        state = state.copyWith(remainingSeconds: newRemaining);
      }
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }
}

/// Provider for the [TimerController] managing exercise countdown.
final timerControllerProvider =
    StateNotifierProvider.autoDispose<TimerController, TimerControllerState>(
  (ref) => TimerController(),
);

/// Provider for a separate rest timer controller.
///
/// Keeps rest timer state independent from the exercise timer.
final restTimerControllerProvider =
    StateNotifierProvider.autoDispose<TimerController, TimerControllerState>(
  (ref) => TimerController(),
);
