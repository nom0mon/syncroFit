import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../shared/models/models.dart';
import '../repositories/progress_log_repository.dart';

class CachingProgressLogRepository implements ProgressLogRepository {
  CachingProgressLogRepository({
    required ProgressLogRepository remote,
    required ConnectivityMonitor connectivity,
    required String userId,
  })  : _remote = remote,
        _connectivity = connectivity,
        _cacheKey = 'progress_logs_$userId';

  final ProgressLogRepository _remote;
  final ConnectivityMonitor _connectivity;
  final String _cacheKey;

  @override
  Future<Result<List<ProgressLog>, AppError>> getAll() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      final result = await _remote.getAll();
      if (result case Success(value: final logs)) await _write(logs);
      return result;
    }
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_cacheKey);
    if (value == null) return const Success([]);
    final logs = (jsonDecode(value) as List<dynamic>)
        .map((item) => ProgressLog.fromJson(item as Map<String, dynamic>))
        .toList();
    return Success(logs);
  }

  @override
  Future<Result<ProgressLog, AppError>> create({
    required String title,
    required String description,
    required double weightKg,
    required Uint8List imageBytes,
    required String imageFilename,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (_connectivity.currentStatus != ConnectivityStatus.online) {
      return Failure(NetworkError());
    }
    final result = await _remote.create(
      title: title,
      description: description,
      weightKg: weightKg,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
      onProgress: onProgress,
    );
    if (result case Success(value: final log)) {
      final current = await getAll();
      if (current case Success(value: final logs)) {
        await _write([log, ...logs.where((e) => e.id != log.id)]);
      }
    }
    return result;
  }

  @override
  Future<Result<void, AppError>> delete(String id) async {
    if (_connectivity.currentStatus != ConnectivityStatus.online) {
      return Failure(NetworkError());
    }
    final result = await _remote.delete(id);
    if (result is Success<void, AppError>) {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_cacheKey);
      if (value != null) {
        final logs = (jsonDecode(value) as List<dynamic>)
            .map((item) => ProgressLog.fromJson(item as Map<String, dynamic>))
            .where((log) => log.id != id)
            .toList();
        await _write(logs);
      }
    }
    return result;
  }

  Future<void> _write(List<ProgressLog> logs) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _cacheKey, jsonEncode(logs.map((e) => e.toJson()).toList()));
  }
}
