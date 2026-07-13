import 'package:synchrofit/data/repositories/notification_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [NotificationRepository] using in-memory data with artificial delays.
class MockNotificationRepository implements NotificationRepository {
  final List<NotificationItem> _notifications = List.of(MockData.notifications);

  @override
  Future<Result<List<NotificationItem>, AppError>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 250));

    // Return sorted by timestamp descending (newest first)
    final sorted = List<NotificationItem>.from(_notifications)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Success(sorted);
  }

  @override
  Future<Result<NotificationItem, AppError>> markAsRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) {
      return Failure(
        NotFoundError(entityType: 'NotificationItem', id: id),
      );
    }

    final notification = _notifications[index];
    final updated = NotificationItem(
      id: notification.id,
      title: notification.title,
      description: notification.description,
      timestamp: notification.timestamp,
      type: notification.type,
      isRead: true,
    );

    _notifications[index] = updated;
    return Success(updated);
  }
}
