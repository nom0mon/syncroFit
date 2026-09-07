/// Configuration constants for the API client.
class ApiConfig {
  ApiConfig._();

  /// Production API URL. Local backend development must override it with:
  /// --dart-define=API_BASE_URL=http://127.0.0.1:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://syncrofit-api.onrender.com',
  );

  /// Request timeout duration.
  static const Duration timeout = Duration(seconds: 30);
}
