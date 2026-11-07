import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the multi-select deletion state on the Progress screen.
///
/// Selection mode is entered by long-pressing a recent-workout card. While
/// active, tapping a card toggles its selection instead of navigating, and a
/// bottom action bar offers a bulk delete. When the selection becomes empty
/// the mode is exited automatically.
class WorkoutSelectionState {
  /// Whether the list is currently in multi-select mode.
  final bool inSelectionMode;

  /// The record ids that are currently selected.
  final Set<String> selectedIds;

  const WorkoutSelectionState({
    this.inSelectionMode = false,
    this.selectedIds = const {},
  });

  WorkoutSelectionState copyWith({
    bool? inSelectionMode,
    Set<String>? selectedIds,
  }) {
    return WorkoutSelectionState(
      inSelectionMode: inSelectionMode ?? this.inSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class WorkoutSelectionNotifier extends StateNotifier<WorkoutSelectionState> {
  WorkoutSelectionNotifier() : super(const WorkoutSelectionState());

  /// Enters selection mode and selects the given [id].
  void enterSelection(String id) {
    state = WorkoutSelectionState(
      inSelectionMode: true,
      selectedIds: {id},
    );
  }

  /// Toggles the selection of the given [id].
  ///
  /// If the selection becomes empty, selection mode is exited automatically.
  void toggleSelection(String id) {
    final ids = Set<String>.from(state.selectedIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }

    if (ids.isEmpty) {
      state = const WorkoutSelectionState();
    } else {
      state = state.copyWith(selectedIds: ids);
    }
  }

  /// Selects all of the given [ids].
  void selectAll(Iterable<String> ids) {
    state = state.copyWith(selectedIds: Set<String>.from(ids));
  }

  /// Exits selection mode and clears the selection.
  void cancel() {
    state = const WorkoutSelectionState();
  }
}

final workoutSelectionProvider =
    StateNotifierProvider<WorkoutSelectionNotifier, WorkoutSelectionState>(
  (ref) => WorkoutSelectionNotifier(),
);
