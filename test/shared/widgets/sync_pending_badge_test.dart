import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/data/sync/sync_engine.dart';
import 'package:synchrofit/data/sync/sync_providers.dart';
import 'package:synchrofit/shared/widgets/sync_pending_badge.dart';

void main() {
  group('SyncPendingBadge', () {
    testWidgets('shows nothing when pendingCount is 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWith(
              (ref) => _FakeSyncStatusNotifier(
                const SyncStatusState(pendingCount: 0),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SyncPendingBadge()),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsNothing);
    });

    testWidgets('displays count when pendingCount > 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWith(
              (ref) => _FakeSyncStatusNotifier(
                const SyncStatusState(pendingCount: 5),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SyncPendingBadge()),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });
  });

  group('SyncStatusListener', () {
    testWidgets('shows sync complete toast on SyncEvent.completed',
        (tester) async {
      final notifier = _FakeSyncStatusNotifier(
        const SyncStatusState(pendingCount: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: SyncStatusListener(
              child: Scaffold(body: Text('content')),
            ),
          ),
        ),
      );

      // Trigger sync completed event.
      notifier.emitEvent(SyncEvent.completed);
      await tester.pumpAndSettle();

      expect(find.text('All changes synced'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows conflict notification on SyncEvent.conflictDetected',
        (tester) async {
      final notifier = _FakeSyncStatusNotifier(
        const SyncStatusState(pendingCount: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: SyncStatusListener(
              child: Scaffold(body: Text('content')),
            ),
          ),
        ),
      );

      // Trigger conflict event.
      notifier.emitEvent(SyncEvent.conflictDetected);
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Your offline change was overridden by a newer server update.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('shows failure notification on SyncEvent.mutationFailed',
        (tester) async {
      final notifier = _FakeSyncStatusNotifier(
        const SyncStatusState(pendingCount: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: SyncStatusListener(
              child: Scaffold(body: Text('content')),
            ),
          ),
        ),
      );

      // Trigger mutation failed event.
      notifier.emitEvent(SyncEvent.mutationFailed);
      await tester.pumpAndSettle();

      expect(
        find.text("Some changes couldn't be synced. Please try again later."),
        findsOneWidget,
      );
    });

    testWidgets('does not show notification for SyncEvent.started',
        (tester) async {
      final notifier = _FakeSyncStatusNotifier(
        const SyncStatusState(pendingCount: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: SyncStatusListener(
              child: Scaffold(body: Text('content')),
            ),
          ),
        ),
      );

      // Trigger started event — should not show any snackbar.
      notifier.emitEvent(SyncEvent.started);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}

/// A fake [SyncStatusNotifier] that allows manually emitting events
/// for testing purposes.
class _FakeSyncStatusNotifier extends StateNotifier<SyncStatusState>
    implements SyncStatusNotifier {
  _FakeSyncStatusNotifier(super.initialState);

  void emitEvent(SyncEvent event) {
    state = state.copyWith(lastEvent: event);
  }

  @override
  Future<void> refreshPendingCount() async {}
}
