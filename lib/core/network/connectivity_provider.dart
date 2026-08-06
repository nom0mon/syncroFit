import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_monitor.dart';
import 'connectivity_monitor_impl.dart';

/// Provides a singleton [ConnectivityMonitor] instance.
///
/// The monitor is created once and reused across the app. It starts
/// listening for platform connectivity changes immediately on creation.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitorImpl();
  ref.onDispose(() => monitor.dispose());
  return monitor;
});

/// StateNotifier that watches the [ConnectivityMonitor.statusStream] and
/// exposes the current [ConnectivityStatus] for UI consumption.
class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityNotifier(this._monitor) : super(_monitor.currentStatus) {
    _subscription = _monitor.statusStream.listen((status) {
      state = status;
    });
  }

  final ConnectivityMonitor _monitor;
  StreamSubscription<ConnectivityStatus>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provides the current [ConnectivityStatus] for UI widgets to watch.
///
/// Usage:
/// ```dart
/// final status = ref.watch(connectivityStatusProvider);
/// if (status == ConnectivityStatus.offline) { ... }
/// ```
final connectivityStatusProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>((ref) {
  final monitor = ref.watch(connectivityMonitorProvider);
  return ConnectivityNotifier(monitor);
});
