import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for notification operations.
abstract class NotificationRepository {
  /// Retrieves all notifications.
  Future<Result<List<NotificationItem>, AppError>> getAll();

  /// Marks a notification as read by its ID.
  Future<Result<NotificationItem, AppError>> markAsRead(String id);
}
