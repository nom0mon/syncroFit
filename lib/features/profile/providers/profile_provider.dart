import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_profile_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [ProfileRepository] instance used throughout the app.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return MockProfileRepository();
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
  /// The user ID used to fetch and manage the profile.
  /// In a real app this would come from auth state; here we use a hardcoded value.
  static const _currentUserId = 'user-001';

  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  Future<UserProfile?> build() async {
    final result = await _repository.getProfile(_currentUserId);

    return switch (result) {
      Success(value: final profile) => profile,
      Failure(error: final error) => _handleLoadError(error),
    };
  }

  /// Handles errors during initial profile load.
  /// Returns null for not-found (profile hasn't been created yet),
  /// throws for other errors so AsyncValue captures them.
  UserProfile? _handleLoadError(AppError error) {
    if (error is NotFoundError) {
      // Profile doesn't exist yet — this is expected for new users.
      return null;
    }
    throw error;
  }

  /// Saves a new user profile (initial profile setup).
  ///
  /// Sets loading state, calls the repository, and updates the async value
  /// with the saved profile or an error.
  Future<void> saveProfile(UserProfile profile) async {
    state = const AsyncValue.loading();

    final result = await _repository.saveProfile(profile);

    state = switch (result) {
      Success(value: final saved) => AsyncValue.data(saved),
      Failure(error: final error) => AsyncValue.error(error, StackTrace.current),
    };
  }

  /// Updates an existing user profile.
  ///
  /// Preserves the previous data during loading via [AsyncValue.guard]-like
  /// pattern so the UI can still show stale data while the update completes.
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
