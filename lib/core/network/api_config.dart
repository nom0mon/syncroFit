/// Configuration constants for the API client.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the API.
  /// Android emulator networking is configured separately for each environment.
  static const String baseUrl = 'http://127.0.0.1:8000';

  /// Request timeout duration.
  static const Duration timeout = Duration(seconds: 30);
}
