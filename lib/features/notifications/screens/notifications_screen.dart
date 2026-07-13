import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/models/models.dart';
import '../providers/notifications_provider.dart';

/// Displays a scrollable list of notifications ordered newest-first.
///
/// Unread notifications are visually distinguished with a different background
/// color and bold title text. Tapping an unread notification marks it as read.
/// Tapping an already-read notification has no effect.
///
/// Shows an empty state when there are no notifications.
///
/// Validates: Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: asyncState.when(
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (state) {
          if (state.errorMessage != null) {
            return ErrorDisplay(
              message: state.errorMessage!,
              onRetry: () => ref.invalidate(notificationsProvider),
            );
          }

          final notifications = state.notifications;

          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              message: 'No notifications yet',
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }
}

/// A single notification list item with read/unread visual distinction.
class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Visual distinction for read vs unread (Req 12.5)
    final backgroundColor = notification.isRead
        ? null
        : colorScheme.surfaceContainerHighest;
    final titleWeight =
        notification.isRead ? FontWeight.normal : FontWeight.bold;

    // Truncate title at 80 chars (Req 12.1)
    final displayTitle = _truncate(notification.title, 80);

    // Truncate description at 200 chars (Req 12.1)
    final displayDescription = _truncate(notification.description, 200);

    // Relative timestamp (Req 12.1)
    final relativeTime = formatRelativeTimestamp(notification.timestamp);

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          // Tap unread → mark as read (Req 12.2)
          // Tap already-read → no change (Req 12.6)
          if (!notification.isRead) {
            ref
                .read(notificationsProvider.notifier)
                .markAsRead(notification.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Read/unread indicator dot
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: Icon(
                  notification.isRead
                      ? Icons.circle_outlined
                      : Icons.circle,
                  size: 12,
                  color: notification.isRead
                      ? colorScheme.outline
                      : colorScheme.primary,
                ),
              ),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: titleWeight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relativeTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Truncates [text] to [maxLength] characters, appending "…" if truncated.
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}…';
  }
}
