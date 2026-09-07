import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import '../../../core/network/connectivity_provider.dart';
import '../../../data/caching/caching_progress_log_repository.dart';
import '../../../data/remote/providers.dart';
import '../../../data/repositories/progress_log_repository.dart';
import '../../../shared/models/models.dart';
import '../../auth/providers/auth_provider.dart';

final progressLogRepositoryProvider = Provider<ProgressLogRepository>((ref) {
  final userId = ref.watch(authStateProvider).user?.id ?? 'anonymous';
  return CachingProgressLogRepository(
    remote: ref.watch(remoteProgressLogRepositoryProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
    userId: userId,
  );
});

final progressLogsProvider =
    AsyncNotifierProvider<ProgressLogsNotifier, List<ProgressLog>>(
  ProgressLogsNotifier.new,
);

class ProgressLogsNotifier extends AsyncNotifier<List<ProgressLog>> {
  ProgressLogRepository get _repository =>
      ref.read(progressLogRepositoryProvider);

  @override
  Future<List<ProgressLog>> build() async {
    final auth = ref.watch(authStateProvider);
    if (!auth.isAuthenticated || auth.user == null) return const [];
    final result = await _repository.getAll();
    return switch (result) {
      Success(value: final logs) => logs
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      Failure(error: final error) => throw error,
    };
  }

  Future<AppError?> create({
    required String title,
    required String description,
    required double weightKg,
    required Uint8List imageBytes,
    required String imageFilename,
    void Function(int, int)? onProgress,
  }) async {
    final result = await _repository.create(
      title: title,
      description: description,
      weightKg: weightKg,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
      onProgress: onProgress,
    );
    switch (result) {
      case Success(value: final log):
        state = AsyncData([log, ...state.valueOrNull ?? const []]);
        return null;
      case Failure(error: final error):
        return error;
    }
  }

  Future<AppError?> delete(String id) async {
    final result = await _repository.delete(id);
    if (result is Success<void, AppError>) {
      state = AsyncData((state.valueOrNull ?? const [])
          .where((log) => log.id != id)
          .toList());
      return null;
    }
    return (result as Failure<void, AppError>).error;
  }
}
