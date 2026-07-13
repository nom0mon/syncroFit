import 'time_slot.dart';

class Trainer {
  final String id;
  final String name;
  final String bio;
  final String specialization;
  final double rating;
  final int experienceYears;
  final List<TimeSlot> availableSlots;
  final String avatarPlaceholder;

  const Trainer({
    required this.id,
    required this.name,
    required this.bio,
    required this.specialization,
    required this.rating,
    required this.experienceYears,
    required this.availableSlots,
    required this.avatarPlaceholder,
  });
}
