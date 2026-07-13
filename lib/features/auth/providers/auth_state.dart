import '../../../shared/models/models.dart';

/// Represents the current authentication state of the application.
class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Whether the user is currently authenticated.
  final bool isAuthenticated;

  /// The authenticated user, or null if unauthenticated.
  final User? user;

  /// Whether an auth operation is in progress.
  final bool isLoading;

  /// An error message from the last failed auth operation, or null.
  final String? errorMessage;

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
