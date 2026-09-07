import 'package:synchrofit/data/repositories/auth_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [AuthRepository] using in-memory data with artificial delays.
class MockAuthRepository implements AuthRepository {
  @override
  Future<Result<User, AppError>> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Valid credentials: mock user's email + any password with 8+ characters
    if (email == MockData.user.email && password.length >= 8) {
      return Success(MockData.user);
    }

    return Failure(AuthError(reason: 'Invalid email or password'));
  }

  @override
  Future<Result<User, AppError>> register(
    String username,
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Registration always succeeds — returns a new user
    final newUser = User(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      firstName: '',
      lastName: '',
      username: username,
      email: email,
      createdAt: DateTime.now(),
    );

    return Success(newUser);
  }

  @override
  Future<Result<void, AppError>> forgotPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 250));

    // Forgot password always succeeds
    return const Success(null);
  }

  @override
  Future<Result<void, AppError>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await Future.delayed(const Duration(milliseconds: 350));

    // and match a known password (mock: "password123")
    if (currentPassword != 'password123') {
      return Failure(AuthError(reason: 'Current password is incorrect'));
    }

    // New password accepted
    return const Success(null);
  }
}
