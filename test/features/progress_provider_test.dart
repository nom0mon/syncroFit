import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/data/repositories/workout_history_repository.dart';
import 'package:synchrofit/data/repositories/workout_repository.dart';
import 'package:synchrofit/features/auth/providers/auth_provider.dart';
import 'package:synchrofit/features/progress/providers/progress_provider.dart';
import 'package:synchrofit/features/workout/providers/workout_provider.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Test [AuthNotifier] that lets tests drive authentication state directly,
/// simulating login, logout, and account switching without a backend.
///
/// Extends the real [AuthNotifier] so it satisfies the [authStateProvider]
/// override closure's return type.
class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref);

  void signIn(User user) {
    state = AuthState(isAuthenticated: true, user: user);
  }

  void signOut() {
    state = const AuthState();
  }
}

/// Records the user ids that history was requested for, and returns a
/// per-user record set so the test can assert identity-scoped reads.
class _RecordingHistoryRepository implements WorkoutHistoryRepository {
  _RecordingHistoryRepository(this._recordsByUser);

  final Map<String, List<WorkoutHistory>> _recordsByUser;
  final List<String> requestedUserIds = [];

  @override
  Future<Result<List<WorkoutHistory>, AppError>> getAll(String userId) async {
    requestedUserIds.add(userId);
    return Success(_recordsByUser[userId] ?? const <WorkoutHistory>[]);
  }

  @override
  Future<Result<List<WorkoutHistory>, AppError>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return Success(_recordsByUser[userId] ?? const <WorkoutHistory>[]);
  }

  @override
  Future<Result<WorkoutHistory, AppError>> save(WorkoutHistory record) async {
    return Success(record);
  }
}

/// Minimal [WorkoutRepository] stub that returns no planned workouts.
class _StubWorkoutRepository implements WorkoutRepository {
  @override
  Future<Result<List<Workout>, AppError>> getAll() async =>
      const Success(<Workout>[]);

  @override
  Future<Result<Workout, AppError>> getById(String id) async =>
      Failure(NotFoundError(entityType: 'Workout', id: id));

  @override
  Future<Result<Workout?, AppError>> getTodaysWorkout() async =>
      const Success(null);
}

User _user(String id) => User(
      id: id,
      firstName: 'User',
      lastName: id,
      email: '$id@example.com',
      createdAt: DateTime(2024, 1, 1),
    );

WorkoutHistory _history(String id, String userId) => WorkoutHistory(
      id: id,
      userId: userId,
      workoutName: 'Session $id',
      completedAt: DateTime(2025, 1, 5, 10),
      totalDurationSeconds: 1800,
      exercisesCompleted: const [],
    );

void main() {
  late _RecordingHistoryRepository historyRepo;
  late _TestAuthNotifier authNotifier;

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        progressWorkoutHistoryRepositoryProvider
            .overrideWithValue(historyRepo),
        workoutRepositoryProvider.overrideWithValue(_StubWorkoutRepository()),
        // The notifier now needs a Ref, so construct it inside the override
        // and capture it for the tests to drive.
        authStateProvider.overrideWith((ref) {
          authNotifier = _TestAuthNotifier(ref);
          return authNotifier;
        }),
      ],
    );
    // Reading the notifier forces the override closure to run so [authNotifier]
    // is constructed before the tests call signIn/signOut. Because
    // progressProvider.build() now watches auth state, the notifier must exist
    // first.
    container.read(authStateProvider.notifier);
    return container;
  }

  setUp(() {
    historyRepo = _RecordingHistoryRepository({
      'user-1': [_history('h1', 'user-1'), _history('h2', 'user-1')],
      'user-2': [_history('h3', 'user-2')],
    });
  });

  test('does not query user-scoped history when unauthenticated', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final state = await container.read(progressProvider.future);

    expect(state.totalWorkouts, 0);
    expect(state.recentHistory, isEmpty);
    // The empty/absent user id must never reach the repository.
    expect(historyRepo.requestedUserIds, isEmpty);
  });

  test('binds history to the authenticated user id', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    authNotifier.signIn(_user('user-1'));

    final state = await container.read(progressProvider.future);

    expect(historyRepo.requestedUserIds, ['user-1']);
    expect(historyRepo.requestedUserIds, isNot(contains('')));
    expect(state.totalWorkouts, 2);
  });

  test('clears user-scoped progress state on logout', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    authNotifier.signIn(_user('user-1'));

    final signedIn = await container.read(progressProvider.future);
    expect(signedIn.totalWorkouts, 2);

    // Logging out must safely reset progress to an empty, unscoped state.
    authNotifier.signOut();
    final afterLogout = await container.read(progressProvider.future);

    expect(afterLogout.totalWorkouts, 0);
    expect(afterLogout.recentHistory, isEmpty);
  });

  test('switches progress state when the account changes', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    authNotifier.signIn(_user('user-1'));

    final firstUser = await container.read(progressProvider.future);
    expect(firstUser.totalWorkouts, 2);

    // Switching accounts must reload history for the new identity only.
    authNotifier.signIn(_user('user-2'));
    final secondUser = await container.read(progressProvider.future);

    expect(secondUser.totalWorkouts, 1);
    expect(historyRepo.requestedUserIds, ['user-1', 'user-2']);
  });
}
