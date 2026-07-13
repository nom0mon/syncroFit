import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_auth_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/models/models.dart';
import 'auth_state.dart';

export 'auth_state.dart';

/// Provides the [AuthRepository] implementation (currently mock).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

/// Provides the current authentication state, managed by [AuthNotifier].
///
/// Screens and the router watch this provider to react to auth changes.
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Manages authentication state and exposes login, register, and
/// forgotPassword operations.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState());

  final Ref _ref;

  AuthRepository get _repository => _ref.read(authRepositoryProvider);

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

  /// Registers a new user with the given [name], [email], and [password].
  ///
  /// On success, sets [AuthState.isAuthenticated] to true and populates the
  /// user. On failure, sets [AuthState.errorMessage].
  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.register(name, email, password);

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

  /// Signs the user out and resets the auth state.
  void logout() {
    state = const AuthState();
  }

  /// Clears the current error message (e.g., after the user dismisses it).
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
