import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchrofit/data/repositories/workout_repository.dart';
import 'package:synchrofit/features/workout/providers/workout_generator_provider.dart';
import 'package:synchrofit/features/workout/providers/workout_provider.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Fake repository implementing the generation + acceptance capabilities so
/// the generator notifier can be exercised without a backend.
class _FakeWorkoutRepository
    implements
        WorkoutRepository,
        WorkoutGenerationRepository,
        WorkoutPlanAcceptanceRepository {
  _FakeWorkoutRepository({required this.acceptResult});

  final Result<List<Workout>, AppError> acceptResult;

  Workout _draft() => const Workout(
        id: '1',
        planId: 'plan-123',
        name: 'Full Body A',
        estimatedDurationMinutes: 30,
        exercises: [],
        isGenerated: true,
        isAccepted: false,
      );

  @override
  Future<Result<List<Workout>, AppError>> generateRecommendation({
    List<int> includedExercises = const [],
    List<int> excludedExercises = const [],
    FitnessLevel? fitnessLevel,
    FitnessGoal? fitnessGoal,
    WorkoutPreference? workoutPreference,
    bool saveOptionsToProfile = false,
  }) async {
    return Success([_draft()]);
  }

  @override
  Future<Result<List<Workout>, AppError>> acceptPlan(String planId) async {
    return acceptResult;
  }

  @override
  Future<Result<List<Workout>, AppError>> getAll() async => const Success([]);

  @override
  Future<Result<Workout, AppError>> getById(String id) async =>
      Failure(NotFoundError(entityType: 'Workout', id: id));

  @override
  Future<Result<Workout?, AppError>> getTodaysWorkout() async =>
      const Success(null);
}

ProviderContainer _containerWith(_FakeWorkoutRepository repo) {
  final container = ProviderContainer(overrides: [
    workoutRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('D3: changing a generation input clears a stale draft', () {
    test('changing workout preference after generating returns to idle', () async {
      final repo = _FakeWorkoutRepository(acceptResult: const Success([]));
      final container = _containerWith(repo);
      final notifier = container.read(workoutGeneratorProvider.notifier);

      await notifier.generate();
      expect(container.read(workoutGeneratorProvider).status,
          WorkoutGeneratorStatus.generated);
      expect(container.read(workoutGeneratorProvider).generatedWorkouts,
          isNotEmpty);

      notifier.setWorkoutPreference(WorkoutPreference.gym);

      final state = container.read(workoutGeneratorProvider);
      expect(state.status, WorkoutGeneratorStatus.idle);
      expect(state.generatedWorkouts, isEmpty);
      expect(state.workoutPreference, WorkoutPreference.gym);
    });

    test('changing a setter with no draft present does not change status', () {
      final repo = _FakeWorkoutRepository(acceptResult: const Success([]));
      final container = _containerWith(repo);
      final notifier = container.read(workoutGeneratorProvider.notifier);

      notifier.setFitnessLevel(FitnessLevel.advanced);

      final state = container.read(workoutGeneratorProvider);
      expect(state.status, WorkoutGeneratorStatus.idle);
      expect(state.fitnessLevel, FitnessLevel.advanced);
    });
  });

  group('D2: accepting a stale plan resets the generator', () {
    test('a 404 on accept drops the draft and asks to regenerate', () async {
      final repo = _FakeWorkoutRepository(
        acceptResult: Failure(
          ServerError(statusCode: 404, serverMessage: 'Not found'),
        ),
      );
      final container = _containerWith(repo);
      final notifier = container.read(workoutGeneratorProvider.notifier);

      await notifier.generate();
      final accepted = await notifier.acceptPlan();

      final state = container.read(workoutGeneratorProvider);
      expect(accepted, isFalse);
      expect(state.status, WorkoutGeneratorStatus.idle);
      expect(state.generatedWorkouts, isEmpty);
      expect(state.errorMessage, contains('generate a new one'));
    });

    test('a transient server error keeps the draft for retry', () async {
      final repo = _FakeWorkoutRepository(
        acceptResult: Failure(
          ServerError(statusCode: 500, serverMessage: 'Server error'),
        ),
      );
      final container = _containerWith(repo);
      final notifier = container.read(workoutGeneratorProvider.notifier);

      await notifier.generate();
      final accepted = await notifier.acceptPlan();

      final state = container.read(workoutGeneratorProvider);
      expect(accepted, isFalse);
      expect(state.status, WorkoutGeneratorStatus.generated);
      expect(state.generatedWorkouts, isNotEmpty);
    });
  });
}
