import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for user profile operations.
abstract class ProfileRepository {
  /// Retrieves the profile for the given user ID.
  Future<Result<UserProfile, AppError>> getProfile(String userId);

  /// Saves a new user profile.
  Future<Result<UserProfile, AppError>> saveProfile(UserProfile profile);

  /// Updates an existing user profile.
  Future<Result<UserProfile, AppError>> updateProfile(UserProfile profile);
}
