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
    test('calls recommendations/current endpoint', () async {
      when(() => mockApiClient.get<List<Workout>>(
            '/api/recommendations/current',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<List<Workout>, AppError>([]));

      await repository.getAll();

      verify(() => mockApiClient.get<List<Workout>>(
            '/api/recommendations/current',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - startSession', () {
    test('sends correct body with workout_id', () async {
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/sessions',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'id': 1,
            'workout_id': 5,
            'status': 'active',
            'started_at': '2024-06-01T10:00:00.000Z',
          }));

      await repository.startSession('5');

      verify(() => mockApiClient.post<Map<String, dynamic>>(
            '/api/sessions',
            body: {'workout_id': '5'},
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - pauseSession', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/sessions/7/pause',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'id': 7,
            'status': 'paused',
          }));

      await repository.pauseSession('7');

      verify(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/sessions/7/pause',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - resumeSession', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/sessions/7/resume',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'id': 7,
            'status': 'active',
          }));

      await repository.resumeSession('7');

      verify(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/sessions/7/resume',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - skipExercise', () {
    test('sends correct body with exercise_id', () async {
      when(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/sessions/3/skip-exercise',
            body: any(named: 'body'),
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<Map<String, dynamic>, AppError>({
            'id': 3,
            'skipped_exercises': ['12'],
          }));

      await repository.skipExercise('3', '12');

      verify(() => mockApiClient.patch<Map<String, dynamic>>(
            '/api/sessions/3/skip-exercise',
            body: {'exercise_id': '12'},
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - completeSession', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.patch<WorkoutSession>(
            '/api/sessions/9/complete',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<WorkoutSession, AppError>(
            WorkoutSession(
              id: '9',
              workoutId: '2',
              workoutName: 'Full Body Workout',
              completedAt: DateTime.parse('2024-06-01T11:00:00.000Z'),
              totalDurationSeconds: 3600,
              exercisesCompleted: 6,
              exercises: [],
            ),
          ));

      await repository.completeSession('9');

      verify(() => mockApiClient.patch<WorkoutSession>(
            '/api/sessions/9/complete',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteWorkoutRepository - generateRecommendation', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.post<List<Workout>>(
            '/api/recommendations/generate',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<List<Workout>, AppError>([]));

      await repository.generateRecommendation();

      verify(() => mockApiClient.post<List<Workout>>(
            '/api/recommendations/generate',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });
}
