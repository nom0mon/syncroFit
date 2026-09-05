import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/remote/remote_workout_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late RemoteWorkoutRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = RemoteWorkoutRepository(mockApiClient);
  });

  group('RemoteWorkoutRepository - getAll', () {
    test('calls workouts endpoint', () async {
      when(() => mockApiClient.get<List<Workout>>(
            '/api/workouts',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => const Success<List<Workout>, AppError>([]));

      await repository.getAll();

      verify(() => mockApiClient.get<List<Workout>>(
            '/api/workouts',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - generateRecommendation', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.post<List<Workout>>(
            '/api/workouts/generate',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => const Success<List<Workout>, AppError>([]));

      await repository.generateRecommendation();

      verify(() => mockApiClient.post<List<Workout>>(
            '/api/workouts/generate',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - getGenerated', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.get<List<Workout>>(
            '/api/workouts/generated',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => const Success<List<Workout>, AppError>([]));

      await repository.getGenerated();

      verify(() => mockApiClient.get<List<Workout>>(
            '/api/workouts/generated',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - customizeExercises', () {
    test('sends only ordered exercise IDs to the customization endpoint', () async {
      const workout = Workout(
        id: '7',
        name: 'Upper A',
        estimatedDurationMinutes: 20,
        exercises: [],
        isGenerated: true,
      );
      when(() => mockApiClient.put<Workout>(
            '/api/workouts/7/exercises',
            body: {'exercise_ids': [4, 2]},
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => const Success<Workout, AppError>(workout));

      final result = await repository.customizeExercises('7', [4, 2]);

      expect(result, isA<Success<Workout, AppError>>());
      verify(() => mockApiClient.put<Workout>(
            '/api/workouts/7/exercises',
            body: {'exercise_ids': [4, 2]},
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });
}
