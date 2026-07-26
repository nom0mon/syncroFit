import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/core/network/token_storage.dart';
import 'package:synchrofit/data/repositories/auth_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Remote implementation of [AuthRepository] that communicates with the
/// Laravel backend via [ApiClient] and manages auth tokens through [TokenStorage].
class RemoteAuthRepository implements AuthRepository {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  RemoteAuthRepository(this._apiClient, this._tokenStorage);

  @override
  Future<Result<User, AppError>> login(String email, String password) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/api/login',
      body: {'email': email, 'password': password},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    switch (result) {
      case Success(value: final data):
        final token = data['token'] as String;
        await _tokenStorage.saveToken(token);
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        return Success(user);
      case Failure(error: final error):
        return Failure(error);
    }
  }

  @override
  Future<Result<User, AppError>> register(
    String name,
    String email,
    String password,
  ) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/api/register',
      body: {'name': name, 'email': email, 'password': password},
      fromJson: (json) => json as Map<String, dynamic>,
    );

    switch (result) {
      case Success(value: final data):
        final token = data['token'] as String;
        await _tokenStorage.saveToken(token);
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        return Success(user);
      case Failure(error: final error):
        return Failure(error);
    }
  }

  @override
  Future<Result<void, AppError>> forgotPassword(String email) async {
    final result = await _apiClient.post<void>(
      '/api/forgot-password',
      body: {'email': email},
    );
    return result;
  }

  /// Logs the user out by calling the backend and clearing the local token.
  ///
  /// The token is always cleared locally regardless of whether the backend
  /// call succeeds, ensuring the user is logged out even on network failure.
  Future<Result<void, AppError>> logout() async {
    final result = await _apiClient.post<void>('/api/logout');
    await _tokenStorage.clearToken();
    return result;
  }

  @override
  Future<Result<void, AppError>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    // Not implemented in the backend yet — return a stub error.
    return Failure(
      ServerError(statusCode: 501, serverMessage: 'Not implemented'),
    );
  }
}
