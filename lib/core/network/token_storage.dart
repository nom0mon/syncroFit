import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/models/user.dart';

/// Securely stores and retrieves the authentication token using Android's
/// encrypted storage facilities.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// Returns the stored authentication token, or null if none exists.
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  /// Persists the given [token] to secure storage.
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Storage not available — token won't persist across refreshes
    }
  }

  /// Persists the authenticated user's identity for offline session restore.
  Future<void> saveUser(User user) async {
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    } catch (_) {
      // Secure storage may be unavailable on unsupported platforms.
    }
  }

  /// Returns the last authenticated user without contacting the backend.
  Future<User?> getUser() async {
    try {
      final encoded = await _storage.read(key: _userKey);
      if (encoded == null) return null;
      return User.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Removes the stored token from secure storage.
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Ignore errors during cleanup
    }
  }

  /// Removes the cached identity when the user explicitly signs out.
  Future<void> clearUser() async {
    try {
      await _storage.delete(key: _userKey);
    } catch (_) {
      // Ignore errors during cleanup.
    }
  }
}
