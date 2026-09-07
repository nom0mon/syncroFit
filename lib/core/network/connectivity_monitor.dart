// Connectivity monitoring abstraction for offline support. It wraps
// platform-level detection and validates server reachability.

/// Represents the current connectivity state of the application.
enum ConnectivityStatus { online, offline }

/// Abstract contract for connectivity monitoring.
///
/// Implementations listen to platform connectivity changes and validate
/// actual server reachability before emitting status updates.
abstract class ConnectivityMonitor {
  /// Stream of connectivity state changes.
  ///
  /// Emits a new value whenever the connectivity status transitions
  /// between online and offline. Transitions are debounced to avoid
  /// flapping on unstable connections.
  Stream<ConnectivityStatus> get statusStream;

  /// Current connectivity status (synchronous snapshot).
  ConnectivityStatus get currentStatus;

  /// Perform a reachability check against the backend.
  ///
  /// Returns `true` if the backend health endpoint responds successfully,
  /// `false` otherwise.
  Future<bool> checkServerReachability();

  /// Release resources (stream subscriptions, timers, etc.).
  void dispose();
}
