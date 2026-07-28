/// Configuration constants for the API client.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the API.
  /// Android emulator uses 10.0.2.2 to reach host machine's localhost.
  /// For iOS simulator, use 127.0.0.1 instead.
  static const String baseUrl = 'http://localhost:8000';

  /// Request timeout duration.
  static const Duration timeout = Duration(seconds: 30);
}
