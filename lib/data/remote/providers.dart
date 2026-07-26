import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../repositories/auth_repository.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/progress_repository.dart';
import 'remote_auth_repository.dart';
import 'remote_exercise_repository.dart';
import 'remote_notification_repository.dart';
import 'remote_profile_repository.dart';
import 'remote_progress_repository.dart';
import 'remote_workout_repository.dart';

/// Provider for [AuthRepository] using the remote implementation.
///
/// Delegates to the Laravel backend via [ApiClient] and stores/clears
/// tokens through [TokenStorage].
final remoteAuthRepositoryProvider = Provider<RemoteAuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return RemoteAuthRepository(apiClient, tokenStorage);
});

/// Provider for [ProfileRepository] using the remote implementation.
///
/// Delegates profile CRUD operations to the Laravel backend via [ApiClient].
final remoteProfileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RemoteProfileRepository(apiClient);
});

/// Provider for [ExerciseRepository] using the remote implementation.
///
/// Delegates exercise listing, detail, search, and filtering to the
/// Laravel backend via [ApiClient].
final remoteExerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RemoteExerciseRepository(apiClient);
});

/// Provider for [WorkoutRepository] using the remote implementation.
///
/// Delegates workout retrieval and session management to the Laravel backend
/// via [ApiClient]. Also exposes session state machine methods (start, pause,
/// resume, skip, complete) beyond the base [WorkoutRepository] interface.
final remoteWorkoutRepositoryProvider =
    Provider<RemoteWorkoutRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RemoteWorkoutRepository(apiClient);
});

/// Provider for [ProgressRepository] using the remote implementation.
///
/// Delegates progress summary, history, and weekly stats to the Laravel
/// backend via [ApiClient].
final remoteProgressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RemoteProgressRepository(apiClient);
});

/// Provider for [NotificationRepository] using the remote implementation.
///
/// Handles FCM device token registration with retry logic and delegates
/// notification operations to the Laravel backend via [ApiClient].
final remoteNotificationRepositoryProvider =
    Provider<RemoteNotificationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RemoteNotificationRepository(apiClient);
});
