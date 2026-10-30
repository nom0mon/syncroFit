import 'enums.dart';

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final DifficultyLevel difficulty;
  final List<String> instructions;
  final String? equipment;
  final List<String> environments;
  final int defaultDurationSeconds;
  final int defaultSets;
  final int defaultReps;
  final String? videoPath;

  /// Joint-impact classification: 'low', 'moderate', or 'high'.
  ///
  /// 'low' means no jumping or explosive ground contact. Used to filter
  /// the preferred/excluded picker when the profile has lowImpactOnly = true,
  /// matching the hard constraint applied by the server's RecommendationEngine.
  final String impactLevel;

  /// Engine-side goal tags for this exercise (e.g. 'muscle_gain', 'fat_loss',
  /// 'general_fitness', 'endurance', 'strength').
  ///
  /// An empty list means the exercise is untagged and is eligible for all
  /// goals. Used to filter the preferred/excluded picker so only exercises
  /// that the RecommendationEngine would score for the selected goal are shown.
  final List<String> goals;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.difficulty,
    required this.instructions,
    this.equipment,
    this.environments = const [],
    required this.defaultDurationSeconds,
    required this.defaultSets,
    required this.defaultReps,
    this.videoPath,
    this.impactLevel = 'low',
    this.goals = const [],
  });

  /// User-facing labels normalized without changing API/cache values.
  String get displayName => _formatLabel(name);
  String get displayMuscleGroup => _formatLabel(muscleGroup);
  String? get displayEquipment {
    final value = equipment?.trim();
    return value == null || value.isEmpty ? null : _formatLabel(value);
  }

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
      environments: (json['environments'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      defaultDurationSeconds: json['default_duration_seconds'] as int,
      defaultSets: json['default_sets'] as int,
      defaultReps: json['default_reps'] as int,
      videoPath: json['video_path'] as String?,
      impactLevel: json['impact_level'] as String? ?? 'low',
      goals: (json['goals'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscle_group': muscleGroup,
        'difficulty': difficulty.name,
        'instructions': instructions,
        'equipment': equipment,
        'environments': environments,
        'default_duration_seconds': defaultDurationSeconds,
        'default_sets': defaultSets,
        'default_reps': defaultReps,
        'video_path': videoPath,
        'impact_level': impactLevel,
        'goals': goals,
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

  static String _formatLabel(String value) {
    final normalized = value.trim().replaceAll('_', ' ').replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
    if (normalized.isEmpty) {
      return normalized;
    }
    final hasIntentionalMixedCase = normalized != normalized.toLowerCase() &&
        normalized != normalized.toUpperCase();
    if (hasIntentionalMixedCase) return normalized;
    return normalized
        .split(' ')
        .map((word) => word
            .split('-')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join('-'))
        .join(' ');
  }
}
