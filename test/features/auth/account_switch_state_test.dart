import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/mock/mock_auth_repository.dart';
import 'package:synchrofit/features/auth/providers/auth_provider.dart';

void main() {
  test('session invalidation clears the authenticated user immediately',
      () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.notifier).login(
          'alex.johnson@example.com',
          'password123',
        );
    expect(container.read(authStateProvider).isAuthenticated, isTrue);
    expect(container.read(authStateProvider).user, isNotNull);

    container.read(authSessionInvalidationProvider.notifier).state++;

    final state = container.read(authStateProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.user, isNull);
  });
}
