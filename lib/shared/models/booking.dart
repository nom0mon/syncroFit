import 'enums.dart';

class Booking {
  final String id;
  final String trainerId;
  final DateTime date;
  final String timeSlot;
  final ConsultationType type;
  final String? notes;

  const Booking({
    required this.id,
    required this.trainerId,
    required this.date,
    required this.timeSlot,
    required this.type,
    this.notes,
  });
}
