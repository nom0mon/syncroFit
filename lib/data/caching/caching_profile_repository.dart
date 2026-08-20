import 'package:uuid/uuid.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../shared/models/models.dart';
import '../local/daos/cache_metadata_dao.dart';
import '../local/daos/profile_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../repositories/profile_repository.dart';

/// Caching decorator for [ProfileRepository] that adds offline persistence
/// and sync-queue integration.
///
/// Online behaviour:
///   - Fetches from the remote repository, persists to the local DAO,
///     and updates cache metadata.
///   - Serves from cache if the cached data is less than 15 minutes old.
///
/// Offline behaviour:
///   - Serves profile data from the local DAO.
///   - Queues profile mutations to the [SyncQueueDao] with a PATCH payload
///     containing only dirty (changed) fields plus an `updated_at` timestamp
///     for conflict resolution.
class CachingProfileRepository implements ProfileRepository {
  final ProfileRepository _remote;
  final ProfileDao _dao;
  final CacheMetadataDao _cacheMetadataDao;
  final SyncQueueDao _syncQueueDao;
  final ConnectivityMonitor _connectivity;

  static const _entityType = 'profile';
  static const _cacheDuration = Duration(minutes: 15);
  static const _uuid = Uuid();

  CachingProfileRepository({
    required ProfileRepository remote,
    required ProfileDao dao,
    required CacheMetadataDao cacheMetadataDao,
    required SyncQueueDao syncQueueDao,
    required ConnectivityMonitor connectivity,
  })  : _remote = remote,
        _dao = dao,
        _cacheMetadataDao = cacheMetadataDao,
        _syncQueueDao = syncQueueDao,
        _connectivity = connectivity;

  @override
  Future<Result<UserProfile, AppError>> getProfile(String userId) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      // Check if cache is still fresh
      final lastSynced = await _cacheMetadataDao.getLastSynced(_entityType);
      if (lastSynced != null &&
          DateTime.now().difference(lastSynced) < _cacheDuration) {
        final cached = await _dao.get();
        if (cached != null) {
          return Success(cached);
        }
      }

      // Fetch from remote, persist to local cache
      final result = await _remote.getProfile(userId);
      if (result is Success<UserProfile, AppError>) {
        await _dao.upsert(result.value);
        await _cacheMetadataDao.updateLastSynced(_entityType, DateTime.now());
      }
      return result;
    }

    // Offline: serve from DAO
    final cached = await _dao.get();
    if (cached != null) {
      return Success(cached);
    }
    return Failure(NetworkError());
  }

  @override
  Future<Result<UserProfile, AppError>> saveProfile(UserProfile profile) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      final result = await _remote.saveProfile(profile);
      if (result is Success<UserProfile, AppError>) {
        await _dao.upsert(result.value);
        await _cacheMetadataDao.updateLastSynced(_entityType, DateTime.now());
      }
      return result;
    }

    // Offline: cache locally and enqueue mutation
    final now = DateTime.now();
    final profileWithTimestamp = UserProfile(
      userId: profile.userId,
      firstName: profile.firstName,
      lastName: profile.lastName,
      age: profile.age,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      gender: profile.gender,
      fitnessGoal: profile.fitnessGoal,
      fitnessLevel: profile.fitnessLevel,
      workoutPreference: profile.workoutPreference,
      workoutAvailability: profile.workoutAvailability,
      updatedAt: now,
    );

    await _dao.upsert(profileWithTimestamp);

    final mutation = SyncMutation(
      id: _uuid.v4(),
      entityType: _entityType,
      entityId: profile.userId,
      operationType: 'create',
      payload: {
        ...profile.toJson(),
        'updated_at': now.toIso8601String(),
      },
      createdAt: now,
    );
    await _syncQueueDao.enqueue(mutation);

    return Success(profileWithTimestamp);
  }

  @override
  Future<Result<UserProfile, AppError>> updateProfile(
      UserProfile profile) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      final result = await _remote.updateProfile(profile);
      if (result is Success<UserProfile, AppError>) {
        await _dao.upsert(result.value);
        await _cacheMetadataDao.updateLastSynced(_entityType, DateTime.now());
      }
      return result;
    }

    // Offline: compute dirty fields, cache, and enqueue PATCH mutation
    final now = DateTime.now();
    final profileWithTimestamp = UserProfile(
      userId: profile.userId,
      firstName: profile.firstName,
      lastName: profile.lastName,
      age: profile.age,
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      gender: profile.gender,
      fitnessGoal: profile.fitnessGoal,
      fitnessLevel: profile.fitnessLevel,
      workoutPreference: profile.workoutPreference,
      workoutAvailability: profile.workoutAvailability,
      updatedAt: now,
    );

    // Get the current cached profile to compute dirty fields
    final existingProfile = await _dao.get();
    final dirtyFields = _computeDirtyFields(existingProfile, profile);

    // Always include updated_at for conflict resolution
    dirtyFields['updated_at'] = now.toIso8601String();

    await _dao.upsert(profileWithTimestamp);

    final mutation = SyncMutation(
      id: _uuid.v4(),
      entityType: _entityType,
      entityId: profile.userId,
      operationType: 'update',
      payload: dirtyFields,
      createdAt: now,
    );
    await _syncQueueDao.enqueue(mutation);

    return Success(profileWithTimestamp);
  }

  /// Computes the fields that differ between the [existing] cached profile
  /// and the [updated] profile. Returns a map with only the changed fields
  /// using the JSON key names.
  Map<String, dynamic> _computeDirtyFields(
    UserProfile? existing,
    UserProfile updated,
  ) {
    // If there's no existing profile, all fields are dirty
    if (existing == null) {
      return updated.toJson();
    }

    final dirty = <String, dynamic>{};
    final updatedJson = updated.toJson();
    final existingJson = existing.toJson();

    for (final key in updatedJson.keys) {
      if (key == 'user_id' || key == 'updated_at') continue;
      final updatedValue = updatedJson[key];
      final existingValue = existingJson[key];
      if (_isDifferent(updatedValue, existingValue)) {
        dirty[key] = updatedValue;
      }
    }

    return dirty;
  }

  /// Compares two values, handling lists by comparing their contents.
  bool _isDifferent(dynamic a, dynamic b) {
    if (a is List && b is List) {
      if (a.length != b.length) return true;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return true;
      }
      return false;
    }
    return a != b;
  }
}
