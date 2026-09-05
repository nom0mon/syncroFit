class ProgressLog {
  const ProgressLog({
    required this.id,
    required this.title,
    required this.description,
    required this.weightKg,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final double weightKg;
  final String imageUrl;
  final DateTime createdAt;

  factory ProgressLog.fromJson(Map<String, dynamic> json) => ProgressLog(
        id: json['id'].toString(),
        title: json['title'] as String,
        description: json['description'] as String,
        weightKg: (json['weight_kg'] as num).toDouble(),
        imageUrl: json['image_url'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'weight_kg': weightKg,
        'image_url': imageUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
