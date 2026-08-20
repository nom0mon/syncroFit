import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import 'api_config.dart';
import 'connectivity_monitor.dart';

/// Concrete implementation of [ConnectivityMonitor].
///
/// Listens to [Connectivity().onConnectivityChanged] and validates actual
/// server reachability by pinging `GET /api/health`. Status transitions
/// are debounced by 2 seconds to avoid flapping on unstable connections.
class ConnectivityMonitorImpl implements ConnectivityMonitor {
  ConnectivityMonitorImpl({
    Connectivity? connectivity,
    Dio? dio,
  })  : _connectivity = connectivity ?? Connectivity(),
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            )) {
    _initialize();
  }

  final Connectivity _connectivity;
  final Dio _dio;

  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _debounceTimer;

  /// Debounce duration to avoid flapping between states.
  static const Duration _debounceDuration = Duration(seconds: 2);

  @override
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  @override
  ConnectivityStatus get currentStatus => _currentStatus;

  @override
  Future<bool> checkServerReachability() async {
    try {
      final response = await _dio.get('/api/health');
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
  }

  void _initialize() {
    // Perform an initial reachability check.
    _performReachabilityCheck();

    // Listen to platform connectivity changes.
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // Cancel any pending debounce timer.
    _debounceTimer?.cancel();

    // Debounce the transition by 2 seconds.
    _debounceTimer = Timer(_debounceDuration, () {
      _performReachabilityCheck();
    });
  }

  Future<void> _performReachabilityCheck() async {
    final hasNoInterface = await _hasNoNetworkInterface();
    if (hasNoInterface) {
      _updateStatus(ConnectivityStatus.offline);
      return;
    }

    final reachable = await checkServerReachability();
    _updateStatus(
      reachable ? ConnectivityStatus.online : ConnectivityStatus.offline,
    );
  }

  /// Quick check whether the device reports no network interfaces at all.
  Future<bool> _hasNoNetworkInterface() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }
}
