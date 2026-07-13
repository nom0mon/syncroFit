import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_notification_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [NotificationRepository] instance used by the notifications module.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return MockNotificationRepository();
});

/// The state exposed by the notifications provider.
class NotificationsState {
  /// The list of notifications ordered by timestamp descending (newest first).
  final List<NotificationItem> notifications;

  /// Error message if something went wrong, null otherwise.
  final String? errorMessage;

  const NotificationsState({
    this.notifications = const [],
    this.errorMessage,
  });

  /// Returns a copy of this state with optional overrides.
  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    String? errorMessage,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      errorMessage: errorMessage,
    );
  }
}

/// Provides the notifications data as an async value, managed by [NotificationsNotifier].
final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsState>(() {
  return NotificationsNotifier();
});

/// An [AsyncNotifier] that manages the notifications list and read state.
class NotificationsNotifier extends AsyncNotifier<NotificationsState> {
  NotificationRepository get _repo =>
      ref.read(notificationRepositoryProvider);

  @override
  Future<NotificationsState> build() async {
    final result = await _repo.getAll();
    return switch (result) {
      Success(value: final notifications) => NotificationsState(
          notifications: notifications,
        ),
      Failure(error: final error) => NotificationsState(
          errorMessage: error.message,
        ),
    };
  }

  /// Marks a notification as read by its [notificationId].
  ///
  /// Updates the local state immediately and persists via the repository.
  /// If the notification is already read, no changes are made.
  ///
  /// Validates: Requirements 12.2
  Future<void> markAsRead(String notificationId) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    // Find the notification
    final index = currentState.notifications
        .indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final notification = currentState.notifications[index];

    // If already read, do nothing
    if (notification.isRead) return;

    // Optimistically update the UI state
    final updatedNotification = NotificationItem(
      id: notification.id,
      title: notification.title,
      description: notification.description,
      timestamp: notification.timestamp,
      type: notification.type,
      isRead: true,
    );

    final updatedList = List<NotificationItem>.from(currentState.notifications);
    updatedList[index] = updatedNotification;

    state = AsyncValue.data(
      currentState.copyWith(notifications: updatedList),
    );

    // Persist to the repository
    await _repo.markAsRead(notificationId);
  }
}
