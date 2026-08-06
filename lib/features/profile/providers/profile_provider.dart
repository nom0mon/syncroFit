import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/caching/caching_providers.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [ProfileRepository] instance used throughout the app.
///
/// Uses [CachingProfileRepository] which wraps the remote repository with
/// local SQLite caching, PATCH-semantics offline mutations, and sync-queue
/// integration. The provider can be overridden with a mock in tests via
/// ProviderScope overrides.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ref.watch(cachingProfileRepositoryProvider);
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
  /// Returns null for all error cases so the app gracefully shows "no profile"
  /// rather than crashing. The edit screen will redirect to profile setup.
  UserProfile? _handleLoadError(AppError error) {
    if (error is NotFoundError) {
      return null;
    }
    if (error is AuthError) {
      return null;
    }
    if (error is NetworkError) {
      return null;
    }
    if (error is ServerError) {
      // Any server error during profile load — treat as "no profile available"
      // This handles 404, 500, CORS issues, etc.
      return null;
    }
    // For any other unrecognized error type, still return null rather than crashing
    return null;
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
