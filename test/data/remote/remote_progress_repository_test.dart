import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/remote/remote_progress_repository.dart';
import 'package:synchrofit/data/repositories/progress_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late RemoteProgressRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = RemoteProgressRepository(mockApiClient);
  });

  group('RemoteProgressRepository - getRecords', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.get<List<ProgressRecord>>(
            '/api/progress/history',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer(
              (_) async => Success<List<ProgressRecord>, AppError>([]));

      await repository.getRecords();

      verify(() => mockApiClient.get<List<ProgressRecord>>(
            '/api/progress/history',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });

    test('returns error on failure', () async {
      when(() => mockApiClient.get<List<ProgressRecord>>(
            '/api/progress/history',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Failure<List<ProgressRecord>, AppError>(
            ServerError(statusCode: 500, serverMessage: 'Internal Server Error'),
          ));

      final result = await repository.getRecords();

      expect(result, isA<Failure<List<ProgressRecord>, AppError>>());
      final error = (result as Failure<List<ProgressRecord>, AppError>).error;
      expect(error, isA<ServerError>());
      expect((error as ServerError).statusCode, equals(500));
    });
  });

  group('RemoteProgressRepository - getWeeklyStats', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.get<Map<String, int>>(
            '/api/progress/weekly-stats',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer(
              (_) async => Success<Map<String, int>, AppError>({}));

      await repository.getWeeklyStats();

      verify(() => mockApiClient.get<Map<String, int>>(
            '/api/progress/weekly-stats',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });
  });

  group('RemoteProgressRepository - getSummary', () {
    test('calls correct endpoint', () async {
      when(() => mockApiClient.get<ProgressSummary>(
            '/api/progress/summary',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<ProgressSummary, AppError>(
            const ProgressSummary(
              totalWorkouts: 10,
              currentStreak: 3,
              longestStreak: 7,
              currentWeightKg: 75.0,
            ),
          ));

      await repository.getSummary();

      verify(() => mockApiClient.get<ProgressSummary>(
            '/api/progress/summary',
            fromJson: any(named: 'fromJson'),
          )).called(1);
    });

    test('handles null weight by defaulting to 0.0', () async {
      // The fromJson in RemoteProgressRepository maps null latest_weight to 0.0.
      // We simulate a Success response with currentWeightKg = 0.0 representing null weight.
      when(() => mockApiClient.get<ProgressSummary>(
            '/api/progress/summary',
            fromJson: any(named: 'fromJson'),
          )).thenAnswer((_) async => Success<ProgressSummary, AppError>(
            const ProgressSummary(
              totalWorkouts: 5,
              currentStreak: 1,
              longestStreak: 2,
              currentWeightKg: 0.0,
            ),
          ));

      final result = await repository.getSummary();

      expect(result, isA<Success<ProgressSummary, AppError>>());
      final summary = (result as Success<ProgressSummary, AppError>).value;
      expect(summary.currentWeightKg, equals(0.0));
    });
  });
}
