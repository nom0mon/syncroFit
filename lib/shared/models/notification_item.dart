import 'enums.dart';

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: _notificationTypeFromJson(json['type'] as String),
      isRead: json['is_read'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'type': _notificationTypeToJson(type),
        'is_read': isRead,
      };

  static NotificationType _notificationTypeFromJson(String value) {
    switch (value) {
      case 'workout_reminder':
        return NotificationType.workoutReminder;
      case 'achievement':
        return NotificationType.achievement;
      case 'community_interaction':
        return NotificationType.communityInteraction;
      case 'system_update':
        return NotificationType.systemUpdate;
      default:
        return NotificationType.systemUpdate;
    }
  }

  static String _notificationTypeToJson(NotificationType type) {
    switch (type) {
      case NotificationType.workoutReminder:
        return 'workout_reminder';
      case NotificationType.achievement:
        return 'achievement';
      case NotificationType.communityInteraction:
        return 'community_interaction';
      case NotificationType.systemUpdate:
        return 'system_update';
    }
  }
}
