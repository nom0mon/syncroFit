class TimeSlot {
  final String id;
  final DateTime date;
  final String time;
  final bool isBooked;

  const TimeSlot({
    required this.id,
    required this.date,
    required this.time,
    required this.isBooked,
  });
}
