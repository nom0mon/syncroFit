import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/remote/remote_exercise_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late RemoteExerciseRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = RemoteExerciseRepository(mockApiClient);
  });

  group('RemoteExerciseRepository - getAll', () {
    test('calls correct endpoint with page_size=100', () async {
      when(() => mockApiClient.get<List<Exercise>>(
            '/api/exercises',
            queryParameters: any(named: 'queryParameters'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<List<Exercise>, AppError>([]));

      await repository.getAll();

      verify(() => mockApiClient.get<List<Exercise>>(
            '/api/exercises',
            queryParameters: {'page_size': 100},
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });

    test('returns parsed exercises on success', () async {
      final exercises = [
        const Exercise(
          id: '1',
          name: 'Push Up',
          muscleGroup: 'chest',
          difficulty: DifficultyLevel.beginner,
          instructions: ['Start in plank position', 'Lower body'],
          equipment: null,
          defaultDurationSeconds: 60,
          defaultSets: 3,
          defaultReps: 12,
          videoPath: '',
        ),
        const Exercise(
          id: '2',
          name: 'Squat',
          muscleGroup: 'legs',
          difficulty: DifficultyLevel.intermediate,
          instructions: ['Stand with feet shoulder-width apart'],
          equipment: 'barbell',
          defaultDurationSeconds: 45,
          defaultSets: 4,
          defaultReps: 10,
          videoPath: '',
        ),
      ];

      when(() => mockApiClient.get<List<Exercise>>(
            '/api/exercises',
            queryParameters: any(named: 'queryParameters'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<List<Exercise>, AppError>(exercises));

      final result = await repository.getAll();

      expect(result, isA<Success<List<Exercise>, AppError>>());
      final list = (result as Success<List<Exercise>, AppError>).value;
      expect(list.length, equals(2));
      expect(list[0].name, equals('Push Up'));
      expect(list[1].name, equals('Squat'));
    });

    test('returns error on failure', () async {
      when(() => mockApiClient.get<List<Exercise>>(
            '/api/exercises',
            queryParameters: any(named: 'queryParameters'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Failure<List<Exercise>, AppError>(
            NetworkError(),
          ));

      final result = await repository.getAll();

      expect(result, isA<Failure<List<Exercise>, AppError>>());
      final error = (result as Failure<List<Exercise>, AppError>).error;
      expect(error, isA<NetworkError>());
    });
  });

  group('RemoteExerciseRepository - getById', () {
    test('calls correct endpoint with id', () async {
      when(() => mockApiClient.get<Exercise>(
            '/api/exercises/42',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Exercise, AppError>(
            const Exercise(
              id: '42',
              name: 'Deadlift',
              muscleGroup: 'back',
              difficulty: DifficultyLevel.advanced,
              instructions: ['Bend at hips'],
              equipment: 'barbell',
              defaultDurationSeconds: 60,
              defaultSets: 5,
              defaultReps: 5,
              videoPath: '',
            ),
          ));

      await repository.getById('42');

      verify(() => mockApiClient.get<Exercise>(
            '/api/exercises/42',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteExerciseRepository - filterByMuscleGroup', () {
    test('passes muscle_group query parameter', () async {
      when(() => mockApiClient.get<List<Exercise>>(
            '/api/exercises',
            queryParameters: any(named: 'queryParameters'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<List<Exercise>, AppError>([]));

      await repository.filterByMuscleGroup(['chest']);

      verify(() => mockApiClient.get<List<Exercise>>(
            '/api/exercises',
            queryParameters: {'page_size': 100, 'muscle_group': 'chest'},
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteExerciseRepository - filterByDifficulty', () {
    test('passes difficulty query parameter', () async {
      when(() => mockApiClient.get<List<Exercise>>(
            '/api/exercises',
            queryParameters: any(named: 'queryParameters'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<List<Exercise>, AppError>([]));

      await repository.filterByDifficulty('advanced');

      verify(() => mockApiClient.get<List<Exercise>>(
            '/api/exercises',
            queryParameters: {'page_size': 100, 'difficulty': 'advanced'},
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });
}
