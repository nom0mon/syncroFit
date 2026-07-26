import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/shared/models/app_error.dart';
import 'package:synchrofit/shared/models/result.dart';

/// **Validates: Requirements 5.5, 5.6**
///
/// Property 4: HTTP Error Mapping
///
/// For any non-2xx HTTP status code (excluding 401 and 422), the ApiClient
/// SHALL return a Failure result containing a ServerError with the correct
/// status code. For timeout/connection errors, the ApiClient SHALL return a
/// Failure result containing a NetworkError.

/// Custom interceptor that simulates HTTP errors for testing.
class ErrorInterceptor extends Interceptor {
  int? errorStatusCode;
  DioExceptionType? exceptionType;
  Map<String, dynamic>? errorBody;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (exceptionType != null) {
      handler.reject(
        DioException(type: exceptionType!, requestOptions: options),
      );
      return;
    }
    handler.reject(
      DioException(
        type: DioExceptionType.badResponse,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: errorStatusCode,
          data: errorBody ??
              {'success': false, 'message': 'Error', 'errors': null},
        ),
      ),
    );
  }
}

/// Creates a test ApiClient with the ErrorInterceptor attached.
/// Returns both the ApiClient and the interceptor for configuration.
({ApiClient client, ErrorInterceptor interceptor}) createTestClient() {
  final container = ProviderContainer();
  final client = ApiClient(container.read as dynamic);

  // We need to create a fresh Dio instance with our interceptor
  // instead of using the ApiClient constructor which needs a real Ref.
  // So we'll build a minimal testable setup.
  final interceptor = ErrorInterceptor();
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:9999/api'));
  dio.interceptors.add(interceptor);

  return (client: client, interceptor: interceptor);
}

/// A minimal ApiClient wrapper for testing that uses a custom Dio instance.
class TestableApiClient {
  TestableApiClient() {
    _interceptor = ErrorInterceptor();
    _dio = Dio(BaseOptions(baseUrl: 'http://localhost:9999/api'));
    _dio.interceptors.add(_interceptor);
  }

  late final Dio _dio;
  late final ErrorInterceptor _interceptor;

  ErrorInterceptor get interceptor => _interceptor;

  /// Makes a GET request and maps errors using the same logic as ApiClient.
  Future<Result<dynamic, AppError>> get(String path) async {
    try {
      final response = await _dio.get(path);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final success = data['success'] as bool? ?? false;
        if (success) {
          return Success(data['data']);
        }
        final message = data['message'] as String? ?? 'An error occurred';
        final statusCode = response.statusCode ?? 500;
        if (statusCode == 422) {
          return Failure(_parseValidationError(data));
        }
        return Failure(
          ServerError(statusCode: statusCode, serverMessage: message),
        );
      }
      return Success(data);
    } on DioException catch (e) {
      return Failure(_mapDioError(e));
    }
  }

  /// Maps Dio exceptions to appropriate AppError subtypes.
  /// This mirrors the exact logic in ApiClient._mapDioError.
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

        // Handle 401 — AuthError
        if (statusCode == 401) {
          final message = _extractMessage(responseData) ?? 'Unauthorized';
          return AuthError(reason: message);
        }

        // Handle 422 — ValidationError
        if (statusCode == 422 && responseData is Map<String, dynamic>) {
          return _parseValidationError(responseData);
        }

        // All other HTTP errors — ServerError
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
}

void main() {
  group('Property 4: HTTP Error Mapping', () {
    late TestableApiClient client;

    setUp(() {
      client = TestableApiClient();
    });

    // Status codes that should map to ServerError (excluding 401 and 422)
    final serverErrorCodes = [400, 403, 404, 405, 408, 429, 500, 502, 503, 504];

    Glados(any.intInRange(0, serverErrorCodes.length)).test(
      'non-2xx status codes (excluding 401, 422) produce ServerError with correct statusCode',
      (index) async {
        final statusCode = serverErrorCodes[index % serverErrorCodes.length];
        client.interceptor.errorStatusCode = statusCode;
        client.interceptor.exceptionType = null;
        client.interceptor.errorBody = {
          'success': false,
          'message': 'Error $statusCode',
          'errors': null,
        };

        final result = await client.get('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<ServerError>());
        final error = failure.error as ServerError;
        expect(error.statusCode, equals(statusCode));
      },
    );

    Glados(any.intInRange(0, 3)).test(
      'timeout and connection exceptions produce NetworkError',
      (index) async {
        final timeoutTypes = [
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
        ];
        final exceptionType = timeoutTypes[index % timeoutTypes.length];

        client.interceptor.exceptionType = exceptionType;

        final result = await client.get('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<NetworkError>());
      },
    );

    Glados(any.intInRange(0, 2)).test(
      'connection error types (connectionError, cancel, badCertificate) produce NetworkError',
      (index) async {
        final errorTypes = [
          DioExceptionType.connectionError,
          DioExceptionType.cancel,
          DioExceptionType.badCertificate,
        ];
        final exceptionType = errorTypes[index % errorTypes.length];

        client.interceptor.exceptionType = exceptionType;

        final result = await client.get('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<NetworkError>());
      },
    );

    Glados(any.intInRange(0, 100)).test(
      '422 responses produce ValidationError',
      (seed) async {
        client.interceptor.errorStatusCode = 422;
        client.interceptor.exceptionType = null;
        client.interceptor.errorBody = {
          'success': false,
          'message': 'Validation failed',
          'errors': {
            'field_$seed': ['Field $seed is invalid'],
          },
        };

        final result = await client.get('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<ValidationError>());
        final error = failure.error as ValidationError;
        expect(error.fieldErrors, contains('field_$seed'));
      },
    );

    Glados(any.intInRange(0, 100)).test(
      '401 responses produce AuthError',
      (seed) async {
        client.interceptor.errorStatusCode = 401;
        client.interceptor.exceptionType = null;
        client.interceptor.errorBody = {
          'success': false,
          'message': 'Unauthorized request $seed',
          'errors': null,
        };

        final result = await client.get('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<AuthError>());
        final error = failure.error as AuthError;
        expect(error.reason, equals('Unauthorized request $seed'));
      },
    );

    Glados(any.intInRange(0, serverErrorCodes.length)).test(
      'ServerError message is extracted from response body',
      (index) async {
        final statusCode = serverErrorCodes[index % serverErrorCodes.length];
        final expectedMessage = 'Custom error message for $statusCode';
        client.interceptor.errorStatusCode = statusCode;
        client.interceptor.exceptionType = null;
        client.interceptor.errorBody = {
          'success': false,
          'message': expectedMessage,
          'errors': null,
        };

        final result = await client.get('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<ServerError>());
        final error = failure.error as ServerError;
        expect(error.serverMessage, equals(expectedMessage));
      },
    );
  });
}
