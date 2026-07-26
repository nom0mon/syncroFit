import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/remote/remote_notification_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late RemoteNotificationRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = RemoteNotificationRepository(mockApiClient);
  });

  group('RemoteNotificationRepository - getAll', () {
    test('sends correct path and returns parsed notifications', () async {
      when(() => mockApiClient.get<List<dynamic>>(
            '/api/notifications',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<List<dynamic>, AppError>([
            {
              'id': 1,
              'title': 'Workout Reminder',
              'description': 'Time for leg day!',
              'timestamp': '2024-06-15T10:00:00.000Z',
              'type': 'workout_reminder',
              'is_read': false,
            },
            {
              'id': 2,
              'title': 'Achievement Unlocked',
              'description': '7-day streak!',
              'timestamp': '2024-06-14T08:00:00.000Z',
              'type': 'achievement',
              'is_read': true,
            },
          ]));

      final result = await repository.getAll();

      expect(result, isA<Success<List<NotificationItem>, AppError>>());
      final notifications =
          (result as Success<List<NotificationItem>, AppError>).value;
      expect(notifications, hasLength(2));
      expect(notifications[0].title, equals('Workout Reminder'));
      expect(notifications[0].isRead, isFalse);
      expect(notifications[1].title, equals('Achievement Unlocked'));
      expect(notifications[1].isRead, isTrue);
    });

    test('returns error on failure', () async {
      when(() => mockApiClient.get<List<dynamic>>(
            '/api/notifications',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer(
        (_) async => Failure<List<dynamic>, AppError>(NetworkError()),
      );

      final result = await repository.getAll();

      expect(result, isA<Failure<List<NotificationItem>, AppError>>());
      final error =
          (result as Failure<List<NotificationItem>, AppError>).error;
      expect(error, isA<NetworkError>());
    });
  });

  group('RemoteNotificationRepository - markAsRead', () {
    test('sends correct path and returns updated notification', () async {
      when(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/notifications/42/read',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer(
        (_) async => Success<Map<String, dynamic>, AppError>({
          'id': 42,
          'title': 'Plan Updated',
          'description': 'Your weekly plan was refreshed',
          'timestamp': '2024-06-15T12:00:00.000Z',
          'type': 'system_update',
          'is_read': true,
        }),
      );

      final result = await repository.markAsRead('42');

      expect(result, isA<Success<NotificationItem, AppError>>());
      final notification =
          (result as Success<NotificationItem, AppError>).value;
      expect(notification.id, equals('42'));
      expect(notification.isRead, isTrue);
      verify(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/notifications/42/read',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });

    test('returns error on failure', () async {
      when(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/notifications/99/read',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer(
        (_) async => Failure<Map<String, dynamic>, AppError>(
          NotFoundError(entityType: 'NotificationItem', id: '99'),
        ),
      );

      final result = await repository.markAsRead('99');

      expect(result, isA<Failure<NotificationItem, AppError>>());
      final error = (result as Failure<NotificationItem, AppError>).error;
      expect(error, isA<NotFoundError>());
    });
  });

  group('RemoteNotificationRepository - registerDeviceToken', () {
    test('sends correct path and body on success', () async {
      when(() => mockApiClient.post<void>(
            '/api/device-tokens',
            body: any(named: 'body'),
          )).thenAnswer((_) async => const Success<void, AppError>(null));

      final result =
          await repository.registerDeviceToken('fcm_token_123', 'device_abc');

      expect(result, isA<Success<void, AppError>>());
      verify(() => mockApiClient.post<void>(
            '/api/device-tokens',
            body: {'token': 'fcm_token_123', 'device_id': 'device_abc'},
          )).called(1);
    });

    test('retries on failure and succeeds on second attempt', () async {
      var callCount = 0;
      when(() => mockApiClient.post<void>(
            '/api/device-tokens',
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return Failure<void, AppError>(NetworkError());
        }
        return const Success<void, AppError>(null);
      });

      final result =
          await repository.registerDeviceToken('token_xyz', 'device_1');

      expect(result, isA<Success<void, AppError>>());
      verify(() => mockApiClient.post<void>(
            '/api/device-tokens',
            body: {'token': 'token_xyz', 'device_id': 'device_1'},
          )).called(2);
    });

    test('returns failure after all 3 retries exhausted', () async {
      when(() => mockApiClient.post<void>(
            '/api/device-tokens',
            body: any(named: 'body'),
          )).thenAnswer(
        (_) async => Failure<void, AppError>(NetworkError()),
      );

      final result =
          await repository.registerDeviceToken('bad_token', 'device_fail');

      expect(result, isA<Failure<void, AppError>>());
      final error = (result as Failure<void, AppError>).error;
      expect(error, isA<NetworkError>());
      // Should have been called exactly 3 times (initial + 2 retries)
      verify(() => mockApiClient.post<void>(
            '/api/device-tokens',
            body: {'token': 'bad_token', 'device_id': 'device_fail'},
          )).called(3);
    });

    test('retries up to 3 times and succeeds on final attempt', () async {
      var callCount = 0;
      when(() => mockApiClient.post<void>(
            '/api/device-tokens',
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount < 3) {
          return Failure<void, AppError>(NetworkError());
        }
        return const Success<void, AppError>(null);
      });

      final result =
          await repository.registerDeviceToken('tok', 'dev');

      expect(result, isA<Success<void, AppError>>());
      verify(() => mockApiClient.post<void>(
            '/api/device-tokens',
            body: {'token': 'tok', 'device_id': 'dev'},
          )).called(3);
    });
  });
}
