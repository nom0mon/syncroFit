import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/data/repositories/workout_repository.dart';
import 'package:synchrofit/features/workout/providers/workout_generator_provider.dart';
import 'package:synchrofit/features/workout/providers/workout_provider.dart';
import 'package:synchrofit/features/workout/screens/workout_generator_screen.dart';
import 'package:synchrofit/shared/models/models.dart';

Exercise _exercise({
  required String id,
  required String name,
  required DifficultyLevel difficulty,
  required List<String> environments,
  String? equipment,
  String impactLevel = 'low',
  List<String> goals = const [],
}) {
  return Exercise(
    id: id,
    name: name,
    muscleGroup: 'chest',
    difficulty: difficulty,
    instructions: const ['Do it'],
    equipment: equipment,
    environments: environments,
    defaultDurationSeconds: 0,
    defaultSets: 3,
    defaultReps: 10,
    impactLevel: impactLevel,
    goals: goals,
  );
}

class _FakeWorkoutRepository
    implements WorkoutRepository, WorkoutGenerationRepository {
  @override
  Future<Result<GenerationResult, AppError>> generateRecommendation({
    List<int> includedExercises = const [],
    List<int> excludedExercises = const [],
    FitnessLevel? fitnessLevel,
    FitnessGoal? fitnessGoal,
    WorkoutPreference? workoutPreference,
    bool saveOptionsToProfile = false,
  }) async =>
      Success(GenerationResult(workouts: const []));

  @override
  Future<Result<List<Workout>, AppError>> getAll() async => const Success([]);

  @override
  Future<Result<Workout, AppError>> getById(String id) async =>
      Failure(NotFoundError(entityType: 'Workout', id: id));

  @override
  Future<Result<Workout?, AppError>> getTodaysWorkout() async =>
      const Success(null);
}

void main() {
  group('eligibleExercisesForProfile', () {
    final gymDumbbellIntermediate = _exercise(
      id: '1',
      name: 'Dumbbell Press',
      difficulty: DifficultyLevel.intermediate,
      environments: const ['gym'],
      equipment: 'dumbbell',
    );
    final homeBodyweightBeginner = _exercise(
      id: '2',
      name: 'Push-Up',
      difficulty: DifficultyLevel.beginner,
      environments: const ['home', 'gym', 'outdoor'],
      equipment: 'bodyweight',
    );
    final gymAdvancedBarbell = _exercise(
      id: '3',
      name: 'Barbell Snatch',
      difficulty: DifficultyLevel.advanced,
      environments: const ['gym'],
      equipment: 'barbell',
    );
    final homeDumbbell = _exercise(
      id: '4',
      name: 'Home Dumbbell Curl',
      difficulty: DifficultyLevel.beginner,
      environments: const ['home'],
      equipment: 'dumbbell',
    );

    final catalog = [
      gymDumbbellIntermediate,
      homeBodyweightBeginner,
      gymAdvancedBarbell,
      homeDumbbell,
    ];

    test('home beginner yields only equipment-free, allowed-difficulty items',
        () {
      final result = eligibleExercisesForProfile(
        catalog,
        fitnessLevel: FitnessLevel.beginner,
        workoutPreference: WorkoutPreference.home,
        fitnessGoal: FitnessGoal.maintainFitness,
      );

      final ids = result.map((e) => e.id).toList();
      // Only the bodyweight home exercise qualifies. The home dumbbell is
      // excluded (equipment), gym items excluded (environment).
      expect(ids, ['2']);
    });

    test('gym beginner excludes advanced difficulty', () {
      final result = eligibleExercisesForProfile(
        catalog,
        fitnessLevel: FitnessLevel.beginner,
        workoutPreference: WorkoutPreference.gym,
        fitnessGoal: FitnessGoal.maintainFitness,
      );

      final ids = result.map((e) => e.id).toSet();
      // beginner allows beginner+intermediate: dumbbell(1) and push-up(2).
      // Advanced barbell(3) is excluded.
      expect(ids, {'1', '2'});
    });

    test('gym advanced excludes beginner difficulty', () {
      final result = eligibleExercisesForProfile(
        catalog,
        fitnessLevel: FitnessLevel.advanced,
        workoutPreference: WorkoutPreference.gym,
        fitnessGoal: FitnessGoal.maintainFitness,
      );

      final ids = result.map((e) => e.id).toSet();
      // advanced allows intermediate+advanced: dumbbell(1) and barbell(3).
      // Beginner push-up(2) is excluded.
      expect(ids, {'1', '3'});
    });

    test('results are sorted alphabetically by display name', () {
      final result = eligibleExercisesForProfile(
        catalog,
        fitnessLevel: FitnessLevel.intermediate,
        workoutPreference: WorkoutPreference.gym,
        fitnessGoal: FitnessGoal.maintainFitness,
      );
      final names = result.map((e) => e.displayName).toList();
      final sorted = [...names]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(names, sorted);
    });
  });

  group('retainEligibleSelections', () {
    ProviderContainer container() {
      final c = ProviderContainer(overrides: [
        workoutRepositoryProvider.overrideWithValue(_FakeWorkoutRepository()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('prunes preferred/excluded IDs that are no longer eligible', () {
      final c = container();
      final notifier = c.read(workoutGeneratorProvider.notifier);

      notifier.toggleIncluded(1);
      notifier.toggleIncluded(99); // becomes ineligible
      notifier.toggleExcluded(2);

      notifier.retainEligibleSelections({1, 2});

      final state = c.read(workoutGeneratorProvider);
      expect(state.includedExerciseIds, {1});
      expect(state.excludedExerciseIds, {2});
    });

    test('is a no-op when all selections remain eligible', () {
      final c = container();
      final notifier = c.read(workoutGeneratorProvider.notifier);

      notifier.toggleIncluded(1);
      notifier.toggleExcluded(2);
      final before = c.read(workoutGeneratorProvider);

      notifier.retainEligibleSelections({1, 2, 3});

      final after = c.read(workoutGeneratorProvider);
      expect(after.includedExerciseIds, before.includedExerciseIds);
      expect(after.excludedExerciseIds, before.excludedExerciseIds);
    });
  });
}
