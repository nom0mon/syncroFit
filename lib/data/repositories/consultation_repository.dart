import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for consultation and trainer operations.
abstract class ConsultationRepository {
  /// Retrieves all available trainers.
  Future<Result<List<Trainer>, AppError>> getTrainers();

  /// Retrieves a single trainer by their ID.
  Future<Result<Trainer, AppError>> getTrainerById(String id);

  /// Creates a new consultation booking.
  Future<Result<Booking, AppError>> createBooking(Booking booking);
}
