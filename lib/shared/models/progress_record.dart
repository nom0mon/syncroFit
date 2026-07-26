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

  factory ProgressRecord.fromJson(Map<String, dynamic> json) {
    return ProgressRecord(
      id: json['id'].toString(),
      date: DateTime.parse(json['recorded_at'] as String),
      weightKg: (json['weight_kg'] as num).toDouble(),
      bmi: (json['bmi'] as num).toDouble(),
      workoutsCompleted: json['workouts_completed'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recorded_at': date.toIso8601String(),
        'weight_kg': weightKg,
        'bmi': bmi,
        'workouts_completed': workoutsCompleted,
      };
}
