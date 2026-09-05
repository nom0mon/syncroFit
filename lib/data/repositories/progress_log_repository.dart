import 'dart:typed_data';

import '../../shared/models/models.dart';

abstract class ProgressLogRepository {
  Future<Result<List<ProgressLog>, AppError>> getAll();

  Future<Result<ProgressLog, AppError>> create({
    required String title,
    required String description,
    required double weightKg,
    required Uint8List imageBytes,
    required String imageFilename,
    void Function(int sent, int total)? onProgress,
  });

  Future<Result<void, AppError>> delete(String id);
}
