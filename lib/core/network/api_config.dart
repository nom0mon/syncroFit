/// Configuration constants for the API client.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the API.
  ///
  /// Resolved at build time from the `API_BASE_URL` dart-define so a build can
  /// target a local Laravel instance (e.g. `http://127.0.0.1:8000`) without
  /// changing source. When no define is supplied, the release-safe fallback is
  /// the deployed HTTPS backend so a forgotten flag never ships a build that
  /// points at localhost.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://syncrofit-api.onrender.com',
  );

  /// Request timeout duration.
  static const Duration timeout = Duration(seconds: 30);
}
