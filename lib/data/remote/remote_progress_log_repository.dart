import 'package:dio/dio.dart';
import 'dart:typed_data';

import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';
import '../repositories/progress_log_repository.dart';

class RemoteProgressLogRepository implements ProgressLogRepository {
  RemoteProgressLogRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<ProgressLog>, AppError>> getAll() =>
      _api.get<List<ProgressLog>>(
        '/api/progress-logs',
        fromJson: (json) {
          final map = json as Map<String, dynamic>;
          return (map['data'] as List<dynamic>)
              .map((item) => ProgressLog.fromJson(item as Map<String, dynamic>))
              .toList();
        },
      );

  @override
  Future<Result<ProgressLog, AppError>> create({
    required String title,
    required String description,
    required double weightKg,
    required Uint8List imageBytes,
    required String imageFilename,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'title': title,
      'description': description,
      'weight_kg': weightKg,
      'image': MultipartFile.fromBytes(imageBytes, filename: imageFilename),
    });
    return _api.postForm<ProgressLog>(
      '/api/progress-logs',
      formData: form,
      onSendProgress: onProgress,
      fromJson: (json) => ProgressLog.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<void, AppError>> delete(String id) =>
      _api.delete('/api/progress-logs/$id');
}
