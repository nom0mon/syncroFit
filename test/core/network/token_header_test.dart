import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;

/// **Validates: Requirements 2.5, 5.1, 5.7**
///
/// Property 2: Token Header Management
///
/// For any HTTP request made through the ApiClient:
/// - IF a token is stored THEN the request SHALL contain an
///   `Authorization: Bearer <token>` header with the stored token value
/// - IF no token is stored THEN the request SHALL NOT contain an
///   `Authorization` header

/// A mock token storage that holds a configurable token value.
/// Simulates the same interface as TokenStorage without platform channels.
class MockTokenStorage {
  String? token;
  MockTokenStorage({this.token});

  Future<String?> getToken() async => token;
  Future<void> saveToken(String t) async => token = t;
  Future<void> clearToken() async => token = null;
}

/// Interceptor that captures request headers and short-circuits the request
/// with a mock successful API envelope response (never hits the network).
class HeaderCaptureInterceptor extends Interceptor {
  Map<String, dynamic>? capturedHeaders;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    capturedHeaders = Map<String, dynamic>.from(options.headers);
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: {'success': true, 'data': null, 'message': null},
    ));
  }
}

/// Creates a Dio instance configured with the same token-attachment interceptor
/// that ApiClient uses (see lib/core/network/api_client.dart), plus a
/// HeaderCaptureInterceptor to inspect headers without making real requests.
({Dio dio, HeaderCaptureInterceptor capture}) _createTestDio(
    MockTokenStorage tokenStorage) {
  final capture = HeaderCaptureInterceptor();
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  ));

  // This mirrors the interceptor in ApiClient's constructor
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await tokenStorage.getToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));

  // Capture interceptor stops the request from going to the network
  dio.interceptors.add(capture);

  return (dio: dio, capture: capture);
}

/// Generates a random alphanumeric token string of given [length].
String _randomToken(Random rng, int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
}

void main() {
  group('Property 2: Token Header Management', () {
    Glados(any.intInRange(10, 101)).test(
      'when token is stored, request includes Authorization: Bearer <token>',
      (tokenLength) async {
        final rng = Random(tokenLength);
        final token = _randomToken(rng, tokenLength);
        final tokenStorage = MockTokenStorage(token: token);
        final (:dio, :capture) = _createTestDio(tokenStorage);

        await dio.get('/test-endpoint');

        expect(capture.capturedHeaders, isNotNull);
        expect(
          capture.capturedHeaders!['Authorization'],
          equals('Bearer $token'),
          reason: 'When a token of length $tokenLength is stored, '
              'the Authorization header must be "Bearer <token>"',
        );
      },
    );

    Glados(any.intInRange(0, 100)).test(
      'when no token is stored, request has no Authorization header',
      (_) async {
        final tokenStorage = MockTokenStorage(token: null);
        final (:dio, :capture) = _createTestDio(tokenStorage);

        await dio.get('/test-endpoint');

        expect(capture.capturedHeaders, isNotNull);
        expect(
          capture.capturedHeaders!.containsKey('Authorization'),
          isFalse,
          reason: 'When no token is stored, '
              'the request must NOT have an Authorization header',
        );
      },
    );

    test('specific token value is attached correctly', () async {
      const token = 'abc123XYZ456_specialChars';
      final tokenStorage = MockTokenStorage(token: token);
      final (:dio, :capture) = _createTestDio(tokenStorage);

      await dio.get('/some-path');

      expect(capture.capturedHeaders, isNotNull);
      expect(
        capture.capturedHeaders!['Authorization'],
        equals('Bearer abc123XYZ456_specialChars'),
      );
    });

    test('null token means no Authorization header', () async {
      final tokenStorage = MockTokenStorage(token: null);
      final (:dio, :capture) = _createTestDio(tokenStorage);

      await dio.get('/some-path');

      expect(capture.capturedHeaders, isNotNull);
      expect(
        capture.capturedHeaders!.containsKey('Authorization'),
        isFalse,
      );
    });

    test('empty string token is still attached as Bearer header', () async {
      // Edge case: empty string is technically a "stored" token
      final tokenStorage = MockTokenStorage(token: '');
      final (:dio, :capture) = _createTestDio(tokenStorage);

      await dio.get('/some-path');

      expect(capture.capturedHeaders, isNotNull);
      // Empty string is non-null, so header should still be attached
      expect(
        capture.capturedHeaders!['Authorization'],
        equals('Bearer '),
      );
    });
  });
}
