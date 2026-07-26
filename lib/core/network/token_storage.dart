import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores and retrieves the authentication token using
/// platform-secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';

  /// Returns the stored authentication token, or null if none exists.
  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  /// Persists the given [token] to secure storage.
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Removes the stored token from secure storage.
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
