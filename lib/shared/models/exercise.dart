import 'enums.dart';

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final DifficultyLevel difficulty;
  final List<String> instructions;
  final String? equipment;
  final int defaultDurationSeconds;
  final int defaultSets;
  final int defaultReps;
  final String? videoPath;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.difficulty,
    required this.instructions,
    this.equipment,
    required this.defaultDurationSeconds,
    required this.defaultSets,
    required this.defaultReps,
    this.videoPath,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'].toString(),
      name: json['name'] as String,
      muscleGroup: json['muscle_group'] as String,
      difficulty: _difficultyFromJson(json['difficulty'] as String),
      instructions: (json['instructions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      equipment: json['equipment'] as String?,
      defaultDurationSeconds: json['default_duration_seconds'] as int,
      defaultSets: json['default_sets'] as int,
      defaultReps: json['default_reps'] as int,
      videoPath: json['video_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscle_group': muscleGroup,
        'difficulty': difficulty.name,
        'instructions': instructions,
        'equipment': equipment,
        'default_duration_seconds': defaultDurationSeconds,
        'default_sets': defaultSets,
        'default_reps': defaultReps,
        'video_path': videoPath,
      };

  static DifficultyLevel _difficultyFromJson(String value) {
    switch (value) {
      case 'beginner':
        return DifficultyLevel.beginner;
      case 'intermediate':
        return DifficultyLevel.intermediate;
      case 'advanced':
        return DifficultyLevel.advanced;
      default:
        return DifficultyLevel.beginner;
    }
  }
}
