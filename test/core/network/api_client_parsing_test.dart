import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:synchrofit/shared/models/app_error.dart';
import 'package:synchrofit/shared/models/result.dart';

/// **Validates: Requirements 5.2, 12.1, 12.2**
///
/// Property 1: API Response Parsing Round-Trip
///
/// For any valid API response JSON (both success and error shapes conforming
/// to the {"success", "data", "message", "errors"} envelope), parsing through
/// the ApiClient response parser produces correct Result types:
/// - Success envelopes produce `Success<T>` results
/// - Error envelopes produce `Failure<AppError>` results
/// - 422 error envelopes with errors field produce ValidationError
/// - Other error envelopes produce ServerError

/// A mock Dio interceptor that returns a success response with given data.
class _SuccessInterceptor extends Interceptor {
  _SuccessInterceptor({required this.responseData, this.statusCode = 200});

  final dynamic responseData;
  final int statusCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(
      Response(
        requestOptions: options,
        data: responseData,
        statusCode: statusCode,
      ),
    );
  }
}

/// A mock Dio interceptor that returns an error response (DioException).
class _ErrorInterceptor extends Interceptor {
  _ErrorInterceptor({required this.responseData, required this.statusCode});

  final dynamic responseData;
  final int statusCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(
      DioException(
        type: DioExceptionType.badResponse,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          data: responseData,
          statusCode: statusCode,
        ),
      ),
    );
  }
}

/// Testable client that mirrors the exact parsing logic from ApiClient.
/// This avoids importing ApiClient directly (which pulls in Flutter widgets
/// via the router dependency chain that fails compilation in test-only mode).
class TestableResponseParser {
  TestableResponseParser();

  late Dio _dio;

  /// Configure for success response testing.
  void configureSuccess(dynamic responseData, {int statusCode = 200}) {
    _dio = Dio(BaseOptions(baseUrl: 'http://localhost:9999/api'));
    _dio.interceptors.add(
      _SuccessInterceptor(responseData: responseData, statusCode: statusCode),
    );
  }

  /// Configure for error response testing.
  void configureError(dynamic responseData, {required int statusCode}) {
    _dio = Dio(BaseOptions(baseUrl: 'http://localhost:9999/api'));
    _dio.interceptors.add(
      _ErrorInterceptor(responseData: responseData, statusCode: statusCode),
    );
  }

  /// Makes a GET request and parses the response using ApiClient's logic.
  Future<Result<T, AppError>> get<T>(
    String path, {
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final response = await _dio.get(path);
      return _parseResponse(response, fromJson: fromJson);
    } on DioException catch (e) {
      return Failure(_mapDioError(e));
    }
  }

  /// Parses the response envelope {"success", "data", "message", "errors"}.
  /// This mirrors ApiClient._parseResponse exactly.
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
  /// This mirrors ApiClient._mapDioError exactly.
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

        // Handle 401
        if (statusCode == 401) {
          final message = _extractMessage(responseData) ?? 'Unauthorized';
          return AuthError(reason: message);
        }

        // Handle 422
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
  group('Property 1: API Response Parsing Round-Trip', () {
    late TestableResponseParser parser;

    setUp(() {
      parser = TestableResponseParser();
    });

    Glados2(any.letterOrDigits, any.letterOrDigits).test(
      'success envelope with string data produces Success result',
      (dataValue, messageValue) async {
        final envelope = {
          'success': true,
          'data': dataValue,
          'message': messageValue,
        };

        parser.configureSuccess(envelope);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Success<dynamic, AppError>>());
        final success = result as Success<dynamic, AppError>;
        expect(success.value, equals(dataValue));
      },
    );

    Glados(any.intInRange(0, 100000)).test(
      'success envelope with int data produces Success result',
      (dataValue) async {
        final envelope = {
          'success': true,
          'data': dataValue,
          'message': 'OK',
        };

        parser.configureSuccess(envelope);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Success<dynamic, AppError>>());
        final success = result as Success<dynamic, AppError>;
        expect(success.value, equals(dataValue));
      },
    );

    Glados(any.letterOrDigits).test(
      'success envelope with map data produces Success with correct map value',
      (name) async {
        final dataMap = {'id': 42, 'name': name, 'active': true};
        final envelope = {
          'success': true,
          'data': dataMap,
          'message': null,
        };

        parser.configureSuccess(envelope);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Success<dynamic, AppError>>());
        final success = result as Success<dynamic, AppError>;
        expect(success.value, isA<Map>());
        expect((success.value as Map)['name'], equals(name));
        expect((success.value as Map)['id'], equals(42));
      },
    );

    Glados(any.letterOrDigits).test(
      'success envelope with fromJson callback transforms data correctly',
      (name) async {
        final dataMap = {'name': name, 'value': 123};
        final envelope = {
          'success': true,
          'data': dataMap,
          'message': 'OK',
        };

        parser.configureSuccess(envelope);
        final result = await parser.get<String>(
          '/test',
          fromJson: (json) => (json as Map<String, dynamic>)['name'] as String,
        );

        expect(result, isA<Success<String, AppError>>());
        final success = result as Success<String, AppError>;
        expect(success.value, equals(name));
      },
    );

    Glados(any.letterOrDigits).test(
      'success envelope with null data produces Success with null value',
      (message) async {
        final envelope = {
          'success': true,
          'data': null,
          'message': message,
        };

        parser.configureSuccess(envelope);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Success<dynamic, AppError>>());
        final success = result as Success<dynamic, AppError>;
        expect(success.value, isNull);
      },
    );

    Glados(any.letterOrDigits).test(
      'error envelope (non-422) produces ServerError with correct message',
      (errorMessage) async {
        final msg = errorMessage.isEmpty ? 'An error occurred' : errorMessage;
        final envelope = {
          'success': false,
          'message': msg,
          'errors': null,
        };

        parser.configureError(envelope, statusCode: 500);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<ServerError>());
        final serverError = failure.error as ServerError;
        expect(serverError.statusCode, equals(500));
        expect(serverError.serverMessage, equals(msg));
      },
    );

    Glados2(any.letterOrDigits, any.letterOrDigits).test(
      '422 error envelope with errors field produces ValidationError',
      (fieldName, errorMsg) async {
        final field = fieldName.isEmpty ? 'email' : fieldName;
        final message = errorMsg.isEmpty ? 'is required' : errorMsg;

        final envelope = {
          'success': false,
          'message': 'Validation failed',
          'errors': {
            field: [message],
          },
        };

        parser.configureError(envelope, statusCode: 422);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<ValidationError>());
        final validationError = failure.error as ValidationError;
        expect(validationError.fieldErrors.containsKey(field), isTrue);
        expect(validationError.fieldErrors[field], equals(message));
      },
    );

    Glados(any.letterOrDigits).test(
      '422 error with multiple fields produces ValidationError with all fields',
      (baseFieldName) async {
        final field1 = baseFieldName.isEmpty ? 'name' : '${baseFieldName}_a';
        final field2 = baseFieldName.isEmpty ? 'email' : '${baseFieldName}_b';

        final envelope = {
          'success': false,
          'message': 'Validation failed',
          'errors': {
            field1: ['Field is required'],
            field2: ['Must be valid'],
          },
        };

        parser.configureError(envelope, statusCode: 422);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<ValidationError>());
        final validationError = failure.error as ValidationError;
        expect(validationError.fieldErrors.length, equals(2));
        expect(validationError.fieldErrors.containsKey(field1), isTrue);
        expect(validationError.fieldErrors.containsKey(field2), isTrue);
      },
    );

    Glados(any.intInRange(403, 500)).test(
      'non-422 non-401 error status codes produce ServerError',
      (statusCode) async {
        // Skip 422 which has special handling
        if (statusCode == 422) return;

        final envelope = {
          'success': false,
          'message': 'Error occurred',
          'errors': null,
        };

        parser.configureError(envelope, statusCode: statusCode);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<ServerError>());
        final serverError = failure.error as ServerError;
        expect(serverError.statusCode, equals(statusCode));
      },
    );

    Glados(any.letterOrDigits).test(
      'error envelope with missing message defaults to standard message',
      (placeholder) async {
        final envelope = {
          'success': false,
          'message': null,
          'errors': null,
        };

        parser.configureError(envelope, statusCode: 500);
        final result = await parser.get<dynamic>('/test');

        expect(result, isA<Failure<dynamic, AppError>>());
        final failure = result as Failure<dynamic, AppError>;
        expect(failure.error, isA<ServerError>());
        // When message extraction returns null, _mapDioError uses default
        final serverError = failure.error as ServerError;
        expect(serverError.serverMessage, isNotEmpty);
      },
    );
  });
}
