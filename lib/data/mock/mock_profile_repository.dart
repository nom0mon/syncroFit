import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [ProfileRepository] using in-memory data with artificial delays.
class MockProfileRepository implements ProfileRepository {
  final Map<String, UserProfile> _profiles = {
    MockData.userProfile.userId: MockData.userProfile,
  };

  @override
  Future<Result<UserProfile, AppError>> getProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final profile = _profiles[userId];
    if (profile == null) {
      return Failure(NotFoundError(entityType: 'UserProfile', id: userId));
    }

    return Success(profile);
  }

  @override
  Future<Result<UserProfile, AppError>> saveProfile(
    UserProfile profile,
  ) async {
    await Future.delayed(const Duration(milliseconds: 350));

    _profiles[profile.userId] = profile;
    return Success(profile);
  }

  @override
  Future<Result<UserProfile, AppError>> updateProfile(
    UserProfile profile,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (!_profiles.containsKey(profile.userId)) {
      return Failure(
        NotFoundError(entityType: 'UserProfile', id: profile.userId),
      );
    }

    _profiles[profile.userId] = profile;
    return Success(profile);
  }
}
