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
  final String imagePlaceholder;

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
    required this.imagePlaceholder,
  });
}
