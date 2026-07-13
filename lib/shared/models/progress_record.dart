class ProgressRecord {
  final String id;
  final DateTime date;
  final double weightKg;
  final double bmi;
  final int workoutsCompleted;

  const ProgressRecord({
    required this.id,
    required this.date,
    required this.weightKg,
    required this.bmi,
    required this.workoutsCompleted,
  });
}
