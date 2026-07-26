import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/core/network/token_storage.dart';
import 'package:synchrofit/data/remote/remote_auth_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late MockApiClient mockApiClient;
  late MockTokenStorage mockTokenStorage;
  late RemoteAuthRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    mockTokenStorage = MockTokenStorage();
    repository = RemoteAuthRepository(mockApiClient, mockTokenStorage);
  });

  group('RemoteAuthRepository - login', () {
    test('sends correct path and body', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/login',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'user': {
              'id': 1,
              'name': 'Test User',
              'email': 'test@test.com',
              'created_at': '2024-01-01T00:00:00.000Z',
            },
            'token': 'test_token_123',
          }));
      when(() => mockTokenStorage.saveToken(any()))
          .thenAnswer((_) async => {});

      await repository.login('test@test.com', 'password123');

      verify(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/login',
            body: {'email': 'test@test.com', 'password': 'password123'},
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });

    test('stores token on success', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/login',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'user': {
              'id': 1,
              'name': 'Test User',
              'email': 'test@test.com',
              'created_at': '2024-01-01T00:00:00.000Z',
            },
            'token': 'auth_token_abc',
          }));
      when(() => mockTokenStorage.saveToken(any()))
          .thenAnswer((_) async => {});

      await repository.login('test@test.com', 'password123');

      verify(() => mockTokenStorage.saveToken('auth_token_abc')).called(1);
    });

    test('returns user on success', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/login',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'user': {
              'id': 42,
              'name': 'Jane Doe',
              'email': 'jane@example.com',
              'created_at': '2024-06-15T10:30:00.000Z',
            },
            'token': 'some_token',
          }));
      when(() => mockTokenStorage.saveToken(any()))
          .thenAnswer((_) async => {});

      final result = await repository.login('jane@example.com', 'secure_pass');

      expect(result, isA<Success<User, AppError>>());
      final user = (result as Success<User, AppError>).value;
      expect(user.id, equals('42'));
      expect(user.name, equals('Jane Doe'));
      expect(user.email, equals('jane@example.com'));
      expect(user.createdAt, equals(DateTime.parse('2024-06-15T10:30:00.000Z')));
    });

    test('returns error on failure', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/login',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Failure<Map<String, dynamic>, AppError>(
            AuthError(reason: 'Invalid email or password'),
          ));

      final result = await repository.login('bad@test.com', 'wrong_pass');

      expect(result, isA<Failure<User, AppError>>());
      final error = (result as Failure<User, AppError>).error;
      expect(error, isA<AuthError>());
      expect((error as AuthError).reason, equals('Invalid email or password'));
      verifyNever(() => mockTokenStorage.saveToken(any()));
    });
  });

  group('RemoteAuthRepository - register', () {
    test('sends correct path and body', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/register',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'user': {
              'id': 5,
              'name': 'New User',
              'email': 'new@test.com',
              'created_at': '2024-03-01T00:00:00.000Z',
            },
            'token': 'new_token',
          }));
      when(() => mockTokenStorage.saveToken(any()))
          .thenAnswer((_) async => {});

      await repository.register('New User', 'new@test.com', 'password123');

      verify(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/register',
            body: {
              'name': 'New User',
              'email': 'new@test.com',
              'password': 'password123',
            },
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });

    test('stores token on success', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/register',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'user': {
              'id': 7,
              'name': 'Registered User',
              'email': 'reg@test.com',
              'created_at': '2024-04-01T00:00:00.000Z',
            },
            'token': 'register_token_xyz',
          }));
      when(() => mockTokenStorage.saveToken(any()))
          .thenAnswer((_) async => {});

      await repository.register('Registered User', 'reg@test.com', 'pass1234');

      verify(() => mockTokenStorage.saveToken('register_token_xyz')).called(1);
    });

    test('returns user on success', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/register',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'user': {
              'id': 99,
              'name': 'Alice Smith',
              'email': 'alice@example.com',
              'created_at': '2024-08-20T15:00:00.000Z',
            },
            'token': 'alice_token',
          }));
      when(() => mockTokenStorage.saveToken(any()))
          .thenAnswer((_) async => {});

      final result =
          await repository.register('Alice Smith', 'alice@example.com', 'pw123456');

      expect(result, isA<Success<User, AppError>>());
      final user = (result as Success<User, AppError>).value;
      expect(user.id, equals('99'));
      expect(user.name, equals('Alice Smith'));
      expect(user.email, equals('alice@example.com'));
      expect(user.createdAt, equals(DateTime.parse('2024-08-20T15:00:00.000Z')));
    });

    test('returns error on failure', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/register',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Failure<Map<String, dynamic>, AppError>(
            ValidationError(fieldErrors: {'email': 'The email has already been taken.'}),
          ));

      final result =
          await repository.register('Test', 'taken@test.com', 'password');

      expect(result, isA<Failure<User, AppError>>());
      final error = (result as Failure<User, AppError>).error;
      expect(error, isA<ValidationError>());
      expect(
        (error as ValidationError).fieldErrors['email'],
        equals('The email has already been taken.'),
      );
      verifyNever(() => mockTokenStorage.saveToken(any()));
    });
  });

  group('RemoteAuthRepository - forgotPassword', () {
    test('sends correct path and body', () async {
      when(() => mockApiClient.post<void>(
            '/api/forgot-password',
            body: any(named: 'body'),
          )).thenAnswer((_) async => const Success<void, AppError>(null));

      await repository.forgotPassword('user@example.com');

      verify(() => mockApiClient.post<void>(
            '/api/forgot-password',
            body: {'email': 'user@example.com'},
          )).called(1);
    });
  });

  group('RemoteAuthRepository - logout', () {
    test('calls backend and clears token', () async {
      when(() => mockApiClient.post<void>('/api/logout'))
          .thenAnswer((_) async => const Success<void, AppError>(null));
      when(() => mockTokenStorage.clearToken())
          .thenAnswer((_) async => {});

      final result = await repository.logout();

      expect(result, isA<Success<void, AppError>>());
      verify(() => mockApiClient.post<void>('/api/logout')).called(1);
      verify(() => mockTokenStorage.clearToken()).called(1);
    });

    test('clears token even on backend failure', () async {
      when(() => mockApiClient.post<void>('/api/logout'))
          .thenAnswer((_) async => Failure<void, AppError>(
                NetworkError(),
              ));
      when(() => mockTokenStorage.clearToken())
          .thenAnswer((_) async => {});

      final result = await repository.logout();

      expect(result, isA<Failure<void, AppError>>());
      // Token should still be cleared even though the backend call failed
      verify(() => mockTokenStorage.clearToken()).called(1);
    });
  });
}
