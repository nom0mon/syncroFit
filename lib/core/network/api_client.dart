import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../router/app_router.dart';
import '../router/route_names.dart';
import 'api_config.dart';
import 'token_storage.dart';

/// Riverpod provider for [TokenStorage].
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Riverpod provider for [ApiClient].
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});

/// Per-request loading state exposed as a Riverpod provider.
/// Screens can watch this to display loading indicators.
final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Incremented whenever the current credentials are no longer valid.
/// Auth state listens to this signal so a 401 cannot leave an authenticated
/// user (and their user-scoped providers) alive in memory.
final authSessionInvalidationProvider = StateProvider<int>((ref) => 0);

/// Centralized HTTP client that handles:
/// - Bearer token attachment on every request
/// - Standard response envelope parsing into Result types
/// - Automatic token clearing and login redirect on 401
/// - Error mapping (422 → ValidationError, timeout → NetworkError, others → ServerError)
/// - Per-request loading state via Riverpod
class ApiClient {
  ApiClient(this._ref) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.timeout,
        receiveTimeout: ApiConfig.timeout,
        sendTimeout: ApiConfig.timeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _ref.read(tokenStorageProvider).getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Ref _ref;
  late final Dio _dio;

  /// Exposes the Dio instance for testing purposes.
  Dio get dio => _dio;

  /// Makes a GET request to [path] and parses the response.
  Future<Result<T, AppError>> get<T>(
    String path, {
    T Function(dynamic json)? fromJson,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request(
      () => _dio.get(path, queryParameters: queryParameters),
      fromJson: fromJson,
    );
  }

  /// Makes a POST request to [path] with optional [body].
  Future<Result<T, AppError>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic json)? fromJson,
  }) async {
    return _request(
      () => _dio.post(path, data: body),
      fromJson: fromJson,
    );
  }

  /// Makes a multipart POST request (used for private media uploads).
  Future<Result<T, AppError>> postForm<T>(
    String path, {
    required FormData formData,
    T Function(dynamic json)? fromJson,
    ProgressCallback? onSendProgress,
  }) async {
    return _request(
      () => _dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onSendProgress,
      ),
      fromJson: fromJson,
    );
  }

  /// Makes a PUT request to [path] with optional [body].
  Future<Result<T, AppError>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic json)? fromJson,
  }) async {
    return _request(
      () => _dio.put(path, data: body),
      fromJson: fromJson,
    );
  }

  /// Makes a PATCH request to [path] with optional [body].
  Future<Result<T, AppError>> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic json)? fromJson,
  }) async {
    return _request(
      () => _dio.patch(path, data: body),
      fromJson: fromJson,
    );
  }

  /// Makes a DELETE request to [path].
  Future<Result<void, AppError>> delete(String path) async {
    return _request<void>(
      () => _dio.delete(path),
    );
  }

  Future<Result<T, AppError>> deleteData<T>(
    String path, {
    T Function(dynamic json)? fromJson,
  }) =>
      _request<T>(() => _dio.delete(path), fromJson: fromJson);

  /// Core request handler that wraps all HTTP calls with:
  /// - Response envelope parsing
  /// - Error mapping
  Future<Result<T, AppError>> _request<T>(
    Future<Response> Function() request, {
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final response = await request();
      return _parseResponse(response, fromJson: fromJson);
    } on DioException catch (e) {
      return Failure(_mapDioError(e));
    } catch (e, stack) {
      debugPrint('ApiClient unexpected error: $e');
      debugPrint('Stack: $stack');
      return Failure(
        ServerError(
            statusCode: 0, serverMessage: 'An unexpected error occurred: $e'),
      );
    }
  }

  /// Parses the response envelope `{"success", "data", "message", "errors"}`.
  Result<T, AppError> _parseResponse<T>(
    Response response, {
    T Function(dynamic json)? fromJson,
  }) {
    final data = response.data;

    if (data is Map<String, dynamic>) {
      final success = data['success'] as bool? ?? false;

      if (success) {
        if (fromJson != null) {
          final parsed = fromJson(data['data']);
          return Success(parsed);
        }
        return Success(data['data'] as T);
      } else {
        // Server returned success: false in body
        final message = data['message'] as String? ?? 'An error occurred';
        final statusCode = response.statusCode ?? 500;

        if (statusCode == 422) {
          return Failure(_parseValidationError(data));
        }

        return Failure(
          ServerError(statusCode: statusCode, serverMessage: message),
        );
      }
    }

    // Fallback: response is not a standard envelope
    if (fromJson != null) {
      return Success(fromJson(data));
    }
    return Success(data as T);
  }

  /// Maps Dio exceptions to appropriate AppError subtypes.
  AppError _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkError();

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 500;
        final responseData = e.response?.data;

        // Handle 401 — clear token and navigate to login
        if (statusCode == 401) {
          developer.log(
            'HTTP 401 ${e.requestOptions.method} ${e.requestOptions.path}; '
            'bearerAttached=${e.requestOptions.headers.containsKey('Authorization')}',
            name: 'SyncroFit.Network',
          );
          _handleUnauthorized(e.requestOptions);
          final message = _extractMessage(responseData) ?? 'Unauthorized';
          return AuthError(reason: message);
        }

        // Handle 422 — parse validation errors
        if (statusCode == 422 && responseData is Map<String, dynamic>) {
          return _parseValidationError(responseData);
        }

        // All other HTTP errors
        final message =
            _extractMessage(responseData) ?? 'Server error occurred';
        return ServerError(statusCode: statusCode, serverMessage: message);

      case DioExceptionType.cancel:
        return NetworkError();

      case DioExceptionType.badCertificate:
        return NetworkError();

      case DioExceptionType.unknown:
      default:
        return NetworkError();
    }
  }

  /// Parses validation error from the response envelope.
  ValidationError _parseValidationError(Map<String, dynamic> data) {
    final errors = data['errors'];
    final fieldErrors = <String, String>{};

    if (errors is Map<String, dynamic>) {
      for (final entry in errors.entries) {
        // Laravel returns arrays of messages per field; take the first one
        if (entry.value is List && (entry.value as List).isNotEmpty) {
          fieldErrors[entry.key] = (entry.value as List).first.toString();
        } else if (entry.value is String) {
          fieldErrors[entry.key] = entry.value as String;
        }
      }
    }

    return ValidationError(fieldErrors: fieldErrors);
  }

  /// Extracts the message string from a response body.
  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String?;
    }
    return null;
  }

  /// Clears the session only when the server rejected the token attached to
  /// this exact request. A late 401 from an older or unauthenticated request
  /// must never erase a token saved by a newer login.
  Future<void> _handleUnauthorized(RequestOptions requestOptions) async {
    final storage = _ref.read(tokenStorageProvider);
    final authorization = requestOptions.headers['Authorization']?.toString();
    if (authorization == null || !authorization.startsWith('Bearer ')) return;

    final rejectedToken = authorization.substring('Bearer '.length);
    final currentToken = await storage.getToken();
    if (currentToken == null || currentToken != rejectedToken) return;

    await storage.clearToken();
    await storage.clearUser();
    _ref.read(authSessionInvalidationProvider.notifier).state++;

    // Navigate to login using the router
    try {
      final router = _ref.read(appRouterProvider);
      router.go(RouteNames.login);
    } catch (_) {
      // Router may not be available in tests or during initialization
    }
  }
}
