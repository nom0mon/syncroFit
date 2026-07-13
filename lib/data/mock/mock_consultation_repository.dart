import 'package:synchrofit/data/repositories/consultation_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [ConsultationRepository] using in-memory data with artificial delays.
class MockConsultationRepository implements ConsultationRepository {
  final List<Trainer> _trainers = List.of(MockData.trainers);
  final List<Booking> _bookings = [];

  @override
  Future<Result<List<Trainer>, AppError>> getTrainers() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Success(List.unmodifiable(_trainers));
  }

  @override
  Future<Result<Trainer, AppError>> getTrainerById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _trainers.indexWhere((t) => t.id == id);
    if (index == -1) {
      return Failure(NotFoundError(entityType: 'Trainer', id: id));
    }
    return Success(_trainers[index]);
  }

  @override
  Future<Result<Booking, AppError>> createBooking(Booking booking) async {
    await Future.delayed(const Duration(milliseconds: 400));

    _bookings.add(booking);
    return Success(booking);
  }
}
