import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for authentication operations.
abstract class AuthRepository {
  /// Authenticates a user with email and password.
  Future<Result<User, AppError>> login(String email, String password);

  /// Registers a new user with first name, last name, email, and password.
  Future<Result<User, AppError>> register(
    String firstName,
    String lastName,
    String email,
    String password,
  );

  /// Sends a password reset request for the given email.
  Future<Result<void, AppError>> forgotPassword(String email);

  /// Changes the user's password given the current and new password.
  Future<Result<void, AppError>> changePassword(
    String currentPassword,
    String newPassword,
  );
}
