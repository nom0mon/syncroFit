import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_consultation_repository.dart';
import '../../../data/repositories/consultation_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [ConsultationRepository] instance used by the consultation module.
final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  return MockConsultationRepository();
});

/// The state exposed by the consultation provider.
class ConsultationState {
  /// The list of all available trainers.
  final List<Trainer> trainers;

  /// Whether the trainer list is currently loading.
  final bool isLoading;

  /// Error message if something went wrong, null otherwise.
  final String? errorMessage;

  const ConsultationState({
    this.trainers = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  /// Returns a copy of this state with optional overrides.
  ConsultationState copyWith({
    List<Trainer>? trainers,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ConsultationState(
      trainers: trainers ?? this.trainers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Provides the consultation data as an async value, managed by [ConsultationNotifier].
final consultationProvider =
    AsyncNotifierProvider<ConsultationNotifier, ConsultationState>(() {
  return ConsultationNotifier();
});

/// An [AsyncNotifier] that manages trainer listings and booking submissions.
class ConsultationNotifier extends AsyncNotifier<ConsultationState> {
  ConsultationRepository get _repo => ref.read(consultationRepositoryProvider);

  @override
  Future<ConsultationState> build() async {
    final result = await _repo.getTrainers();
    return switch (result) {
      Success(value: final trainers) => ConsultationState(trainers: trainers),
      Failure(error: final error) =>
        ConsultationState(errorMessage: error.message),
    };
  }

  /// Returns a trainer by their ID, or null if not found in the current state.
  Trainer? getTrainerById(String trainerId) {
    final currentState = state.valueOrNull;
    if (currentState == null) return null;

    try {
      return currentState.trainers.firstWhere((t) => t.id == trainerId);
    } catch (_) {
      return null;
    }
  }

  /// Submits a booking for a consultation.
  ///
  /// Creates a [Booking] with the provided parameters and saves it to the
  /// mock repository. Returns `true` on success, `false` on failure.
  ///
  /// Validates: Requirements 11.5
  Future<bool> submitBooking({
    required String trainerId,
    required DateTime date,
    required String timeSlot,
    required ConsultationType consultationType,
    String? notes,
  }) async {
    final booking = Booking(
      id: 'booking_${DateTime.now().millisecondsSinceEpoch}',
      trainerId: trainerId,
      date: date,
      timeSlot: timeSlot,
      type: consultationType,
      notes: notes,
    );

    final result = await _repo.createBooking(booking);
    return switch (result) {
      Success() => true,
      Failure() => false,
    };
  }
}

/// A convenience provider to get a single trainer by ID.
///
/// Fetches trainer details from the repository directly (useful when
/// navigating to a trainer profile from a deep link or when the trainer
/// list hasn't been loaded yet).
final trainerDetailProvider =
    FutureProvider.family<Trainer?, String>((ref, trainerId) async {
  // First try to get from the already-loaded state
  final consultationState = ref.watch(consultationProvider);
  final trainerFromState = consultationState.whenOrNull(
    data: (state) {
      try {
        return state.trainers.firstWhere((t) => t.id == trainerId);
      } catch (_) {
        return null;
      }
    },
  );

  if (trainerFromState != null) {
    return trainerFromState;
  }

  // Fallback: fetch directly from repository
  final repo = ref.read(consultationRepositoryProvider);
  final result = await repo.getTrainerById(trainerId);
  return switch (result) {
    Success(value: final trainer) => trainer,
    Failure() => null,
  };
});
