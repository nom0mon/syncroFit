import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

/// Remote implementation of [ProfileRepository] that delegates to the
/// Laravel backend via [ApiClient].
///
/// Backend endpoints:
/// - GET  /api/profile → retrieve authenticated user's profile
/// - POST /api/profile → create profile
/// - PUT  /api/profile → update profile
///
/// The backend uses the authenticated user's token to identify the user,
/// so the [userId] parameter in [getProfile] is not sent to the server.
class RemoteProfileRepository implements ProfileRepository {
  final ApiClient _apiClient;

  RemoteProfileRepository(this._apiClient);

  @override
  Future<Result<UserProfile, AppError>> getProfile(String userId) async {
    final result = await _apiClient.get<UserProfile>(
      '/api/profile',
      fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
    return result;
  }

  @override
  Future<Result<UserProfile, AppError>> saveProfile(UserProfile profile) async {
    final result = await _apiClient.post<UserProfile>(
      '/api/profile',
      body: profile.toJson(),
      fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
    return result;
  }

  @override
  Future<Result<UserProfile, AppError>> updateProfile(
      UserProfile profile) async {
    final result = await _apiClient.put<UserProfile>(
      '/api/profile',
      body: profile.toJson(),
      fromJson: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
    );
    return result;
  }
}
