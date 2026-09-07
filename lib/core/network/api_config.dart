/// Configuration constants for the API client.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the API. Override it in tester/production builds with:
  /// --dart-define=API_BASE_URL=https://your-api.example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Request timeout duration.
  static const Duration timeout = Duration(seconds: 30);
}
