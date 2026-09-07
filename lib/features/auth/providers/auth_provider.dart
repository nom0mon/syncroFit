import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/remote/remote_auth_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/models/models.dart';
import 'auth_state.dart';

export 'auth_state.dart';

/// Provides the [AuthRepository] implementation.
///
/// Uses [RemoteAuthRepository] backed by the Laravel API. The provider can
/// be overridden with a mock in tests via ProviderScope overrides.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return RemoteAuthRepository(apiClient, tokenStorage);
});

/// Provides the current authentication state, managed by [AuthNotifier].
///
/// Screens and the router watch this provider to react to auth changes.
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Manages authentication state and exposes login, register, and
/// forgotPassword operations.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref, {bool restoreSession = true})
      : super(AuthState(isLoading: restoreSession)) {
    _ref.listen<int>(authSessionInvalidationProvider, (previous, next) {
      if (previous != null && previous != next && mounted) {
        state = const AuthState();
      }
    });
    if (restoreSession) {
      _restoreSession();
    }
  }

  final Ref _ref;

  AuthRepository get _repository => _ref.read(authRepositoryProvider);

  /// Convenience getter for the remote auth repository which exposes logout.
  RemoteAuthRepository get _remoteRepo =>
      _ref.read(authRepositoryProvider) as RemoteAuthRepository;

  Future<void> _restoreSession() async {
    final storage = _ref.read(tokenStorageProvider);
    final token = await storage.getToken();
    final user = await storage.getUser();
    if (!mounted) return;
    state = token != null && token.isNotEmpty && user != null
        ? AuthState(isAuthenticated: true, user: user)
        : const AuthState();
  }

  /// Attempts to log in with the given [email] and [password].
  ///
  /// On success, sets [AuthState.isAuthenticated] to true and populates the
  /// user. On failure, sets [AuthState.errorMessage] with the error description.
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.login(email, password);

    switch (result) {
      case Success(value: final user):
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          isLoading: false,
        );
      case Failure(error: final error):
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        );
    }
  }

  /// Registers a new user with the given [username], [email], and [password].
  ///
  /// On success, sets [AuthState.isAuthenticated] to true and populates the
  /// user. On failure, sets [AuthState.errorMessage].
  Future<void> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.register(username, email, password);

    switch (result) {
      case Success(value: final user):
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          isLoading: false,
        );
      case Failure(error: final error):
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        );
    }
  }

  /// Sends a password-reset request for the given [email].
  ///
  /// On failure, sets [AuthState.errorMessage]. On success, clears any
  /// existing error (the UI should show a confirmation message).
  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.forgotPassword(email);

    switch (result) {
      case Success():
        state = state.copyWith(isLoading: false);
        return true;
      case Failure(error: final error):
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        );
        return false;
    }
  }

  /// Signs the user out by calling the backend logout endpoint, clearing
  /// the stored token, and resetting local auth state.
  ///
  /// The token is always cleared locally regardless of whether the backend
  /// call succeeds, ensuring the user is logged out even on network failure
  /// (per Requirement 4.4).
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _remoteRepo.logout();
    state = const AuthState();
  }

  /// Clears the current error message (e.g., after the user dismisses it).
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> updateCachedIdentity({
    required String firstName,
    required String lastName,
    required String username,
  }) async {
    final current = state.user;
    if (current == null) return;
    final updated = User(
      id: current.id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: current.email,
      createdAt: current.createdAt,
    );
    await _ref.read(tokenStorageProvider).saveUser(updated);
    state = state.copyWith(user: updated);
  }
}
