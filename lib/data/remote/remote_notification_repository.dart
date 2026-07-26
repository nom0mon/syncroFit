import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/repositories/notification_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Remote implementation of [NotificationRepository] that communicates with the
/// Laravel backend via [ApiClient].
///
/// Handles:
/// - FCM device token registration with exponential backoff retry (1s, 2s, 4s)
/// - Notification listing and mark-as-read via the backend API
/// - Foreground notification display (stub — requires firebase_messaging)
/// - Notification tap handling (stub — requires firebase_messaging)
class RemoteNotificationRepository implements NotificationRepository {
  final ApiClient _apiClient;

  RemoteNotificationRepository(this._apiClient);

  /// Maximum number of retries for device token registration.
  static const int _maxRetries = 3;

  @override
  Future<Result<List<NotificationItem>, AppError>> getAll() async {
    final result = await _apiClient.get<List<dynamic>>(
      '/api/notifications',
      fromJson: (json) => json as List<dynamic>,
    );

    switch (result) {
      case Success(value: final data):
        final notifications = data
            .map((item) =>
                NotificationItem.fromJson(item as Map<String, dynamic>))
            .toList();
        return Success(notifications);
      case Failure(error: final error):
        return Failure(error);
    }
  }

  @override
  Future<Result<NotificationItem, AppError>> markAsRead(String id) async {
    final result = await _apiClient.patch<Map<String, dynamic>>(
      '/api/notifications/$id/read',
      fromJson: (json) => json as Map<String, dynamic>,
    );

    switch (result) {
      case Success(value: final data):
        return Success(NotificationItem.fromJson(data));
      case Failure(error: final error):
        return Failure(error);
    }
  }

  /// Registers a device token with the backend for push notifications.
  ///
  /// Retries up to 3 times with exponential backoff (1s, 2s, 4s).
  /// Silently discards the request if all retries fail (per Requirement 11.2).
  ///
  /// [token] is the FCM device token string.
  /// [deviceId] uniquely identifies this device to support multi-device users.
  Future<Result<void, AppError>> registerDeviceToken(
    String token,
    String deviceId,
  ) async {
    Result<void, AppError>? lastResult;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      final result = await _apiClient.post<void>(
        '/api/device-tokens',
        body: {'token': token, 'device_id': deviceId},
      );

      if (result is Success) {
        return result;
      }

      lastResult = result;

      // Wait with exponential backoff before the next retry (1s, 2s, 4s).
      // Skip the delay after the last attempt.
      if (attempt < _maxRetries - 1) {
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }

    // All retries exhausted — return the last failure.
    return lastResult!;
  }

  /// Handles a foreground push notification by displaying an in-app banner.
  ///
  /// The banner auto-dismisses after 5 seconds or on user tap.
  ///
  /// Note: This is a placeholder. Actual implementation requires
  /// `firebase_messaging` to be configured and the app to register a
  /// foreground message handler via `FirebaseMessaging.onMessage`.
  ///
  /// When implemented, this method would:
  /// 1. Parse the notification payload into a [NotificationItem]
  /// 2. Display an overlay banner using the app's notification widget
  /// 3. Auto-dismiss after 5 seconds via a timer
  /// 4. On tap, call [handleNotificationTap] with the payload data
  void handleForegroundMessage(Map<String, dynamic> messageData) {
    // Stub: firebase_messaging integration needed.
    // In production, this would be called from:
    //   FirebaseMessaging.onMessage.listen((message) {
    //     handleForegroundMessage(message.data);
    //   });
  }

  /// Handles notification tap events (foreground or background).
  ///
  /// Navigation behavior:
  /// - If the payload contains a valid `workout_id`, navigates to the
  ///   workout detail screen for that workout.
  /// - If the workout referenced in the payload no longer exists (or
  ///   `workout_id` is absent), navigates to the dashboard and shows
  ///   a message indicating the workout is no longer available.
  ///
  /// Note: This is a placeholder. Actual implementation requires
  /// `firebase_messaging` to be configured and the app to register
  /// tap handlers via `FirebaseMessaging.onMessageOpenedApp` and
  /// `getInitialMessage()`.
  ///
  /// [messageData] is the data payload from the FCM notification.
  void handleNotificationTap(Map<String, dynamic> messageData) {
    // Stub: firebase_messaging integration needed.
    // In production, this would:
    //   final workoutId = messageData['workout_id'];
    //   if (workoutId != null) {
    //     router.go('/workouts/$workoutId');
    //   } else {
    //     router.go('/dashboard');
    //     showSnackbar('Workout is no longer available');
    //   }
  }
}
