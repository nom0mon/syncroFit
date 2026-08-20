import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores and retrieves the authentication token.
///
/// Uses flutter_secure_storage which backs to:
/// - Keychain on iOS
/// - EncryptedSharedPreferences on Android
/// - localStorage on Web (with dbName and publicKey options)
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              webOptions: WebOptions(
                dbName: 'SyncroFitAuth',
                publicKey: 'SyncroFitAuthKey',
              ),
            );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';

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

  /// Removes the stored token from secure storage.
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Ignore errors during cleanup
    }
  }
}
