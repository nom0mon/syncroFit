import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../data/remote/remote_auth_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/models/models.dart';

// ─── SharedPreferences Provider ───────────────────────────────────────────────

/// Provides the [SharedPreferences] instance.
///
/// Must be overridden in the root ProviderScope with an already-initialized
/// instance (see main.dart).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with an initialized instance.',
  );
});

// ─── Theme Provider ───────────────────────────────────────────────────────────

const _themeModeKey = 'theme_mode';

/// Provides the current [ThemeMode], persisted to SharedPreferences.
///
/// Values stored as int: 0 = system, 1 = light, 2 = dark.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

/// Manages theme state and persists changes to SharedPreferences.
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(this._prefs) : super(_loadTheme(_prefs));

  final SharedPreferences _prefs;

  static ThemeMode _loadTheme(SharedPreferences prefs) {
    final index = prefs.getInt(_themeModeKey);
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return ThemeMode.dark;
    }
    return ThemeMode.values[index];
  }

  /// Sets the theme mode and persists the choice.
  void setThemeMode(ThemeMode mode) {
    state = mode;
    _prefs.setInt(_themeModeKey, mode.index);
  }

  /// Convenience toggle between light and dark mode.
  void toggle() {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newMode);
  }
}

// ─── Change Password ──────────────────────────────────────────────────────────

/// State representing the outcome of a change-password operation.
class ChangePasswordState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;

  const ChangePasswordState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  ChangePasswordState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChangePasswordState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Provides the [AuthRepository] for settings operations.
final settingsAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return RemoteAuthRepository(apiClient, tokenStorage);
});

/// Provides the change-password state and exposes the [changePassword] method.
final changePasswordProvider =
    StateNotifierProvider<ChangePasswordNotifier, ChangePasswordState>((ref) {
  final repository = ref.watch(settingsAuthRepositoryProvider);
  return ChangePasswordNotifier(repository);
});

/// Manages change-password logic calling the [AuthRepository].
class ChangePasswordNotifier extends StateNotifier<ChangePasswordState> {
  ChangePasswordNotifier(this._repository) : super(const ChangePasswordState());

  final AuthRepository _repository;

  /// Attempts to change the password via the repository.
  ///
  /// On success, sets [ChangePasswordState.isSuccess] to true.
  /// On failure, populates [ChangePasswordState.errorMessage].
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    state = const ChangePasswordState(isLoading: true);

    final result = await _repository.changePassword(
      currentPassword,
      newPassword,
    );

    switch (result) {
      case Success():
        state = const ChangePasswordState(isSuccess: true);
        return true;
      case Failure(error: final error):
        state = ChangePasswordState(errorMessage: error.message);
        return false;
    }
  }

  /// Resets the state (e.g., after showing success confirmation or clearing form).
  void reset() {
    state = const ChangePasswordState();
  }
}
