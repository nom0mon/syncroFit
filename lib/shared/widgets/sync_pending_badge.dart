import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sync/sync_engine.dart';
import '../../data/sync/sync_providers.dart';

/// A small circular badge showing the number of pending sync mutations.
///
/// Watches [syncStatusProvider] and displays a count when `pendingCount > 0`.
/// Returns [SizedBox.shrink] when there are no pending mutations.
///
/// Typically placed next to a sync icon in the app bar or navigation area.
class SyncPendingBadge extends ConsumerWidget {
  const SyncPendingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = syncStatus.pendingCount;

    if (pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sync,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$pendingCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that listens to [syncStatusProvider] for sync events and
/// shows the appropriate SnackBars:
///
/// - **Sync complete**: brief "All changes synced" toast (2-3 seconds)
/// - **Conflict/failure**: longer "Some changes couldn't be synced" snackbar (5 seconds)
///
/// Wrap your main content with this widget to enable automatic sync
/// notifications:
///
/// ```dart
/// SyncStatusListener(
///   child: Scaffold(...),
/// )
/// ```
class SyncStatusListener extends ConsumerStatefulWidget {
  const SyncStatusListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncStatusListener> createState() =>
      _SyncStatusListenerState();
}

class _SyncStatusListenerState extends ConsumerState<SyncStatusListener> {
  SyncEvent? _previousEvent;

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncStatusState>(syncStatusProvider, (previous, next) {
      final lastEvent = next.lastEvent;

      // Only react to new events (avoid duplicate notifications).
      if (lastEvent == null || lastEvent == _previousEvent) return;
      _previousEvent = lastEvent;

      switch (lastEvent) {
        case SyncEvent.completed:
          _showSyncCompleteToast(context);
          break;
        case SyncEvent.conflictDetected:
          _showConflictNotification(
            context,
            'Your offline change was overridden by a newer server update.',
          );
          break;
        case SyncEvent.mutationFailed:
          _showConflictNotification(
            context,
            "Some changes couldn't be synced. Please try again later.",
          );
          break;
        case SyncEvent.started:
          // No UI notification needed for sync start.
          break;
      }
    });

    return widget.child;
  }

  /// Shows a brief "All changes synced" toast for 2 seconds.
  void _showSyncCompleteToast(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('All changes synced'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade700,
        ),
      );
  }

  /// Shows a conflict/failure notification snackbar for 5 seconds with
  /// a dismiss action.
  void _showConflictNotification(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
  }
}
