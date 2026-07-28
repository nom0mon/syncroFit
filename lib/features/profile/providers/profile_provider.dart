import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/remote/remote_profile_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [ProfileRepository] instance used throughout the app.
///
/// Uses [RemoteProfileRepository] backed by the Laravel API. The provider
/// can be overridden with a mock in tests via ProviderScope overrides.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RemoteProfileRepository(apiClient);
});

/// Provides the user's profile as an async value, managed by [ProfileNotifier].
///
/// Fetches the current user's profile on initialization and exposes
/// [saveProfile] and [updateProfile] methods for mutations.
final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile?>(() {
  return ProfileNotifier();
});

/// An [AsyncNotifier] that manages loading and mutating the user's profile.
class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  Future<UserProfile?> build() async {
    // Check if we have a token before making the request.
    // If not authenticated, return null silently — no need to hit the server.
    final token = await ref.read(tokenStorageProvider).getToken();
    if (token == null) {
      return null;
    }

    final result = await _repository.getProfile('');

    return switch (result) {
      Success(value: final profile) => profile,
      Failure(error: final error) => _handleLoadError(error),
    };
  }

  /// Handles errors during initial profile load.
  /// Returns null for expected cases (not found, not authenticated, network issues),
  /// throws for unexpected errors so AsyncValue captures them.
  UserProfile? _handleLoadError(AppError error) {
    if (error is NotFoundError) {
      // Profile doesn't exist yet — expected for new users.
      return null;
    }
    if (error is AuthError) {
      // User is not authenticated — expected on app startup before login.
      return null;
    }
    if (error is NetworkError) {
      // Backend unreachable — don't crash the app, just return null.
      return null;
    }
    if (error is ServerError && error.statusCode == 404) {
      // Profile not found via server error envelope.
      return null;
    }
    throw error;
  }

  /// Saves a new user profile (initial profile setup).
  Future<void> saveProfile(UserProfile profile) async {
    state = const AsyncValue.loading();

    final result = await _repository.saveProfile(profile);

    state = switch (result) {
      Success(value: final saved) => AsyncValue.data(saved),
      Failure(error: final error) =>
        AsyncValue.error(error, StackTrace.current),
    };
  }

  /// Updates an existing user profile.
  Future<void> updateProfile(UserProfile profile) async {
    final previous = state.valueOrNull;
    state = const AsyncValue.loading();

    final result = await _repository.updateProfile(profile);

    state = switch (result) {
      Success(value: final updated) => AsyncValue.data(updated),
      Failure(error: final error) =>
        AsyncValue<UserProfile?>.error(error, StackTrace.current)
            .copyWithPrevious(AsyncValue<UserProfile?>.data(previous)),
    };
  }
}
