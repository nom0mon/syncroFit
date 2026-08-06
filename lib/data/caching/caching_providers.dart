import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_provider.dart';
import '../local/database_provider.dart';
import '../local/local_database.dart';
import '../remote/providers.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/workout_repository.dart';
import 'caching_exercise_repository.dart';
import 'caching_profile_repository.dart';
import 'caching_progress_repository.dart';
import 'caching_workout_repository.dart';

/// Provides a [CachingExerciseRepository] that wraps the remote repository
/// with local SQLite caching and cache freshness logic.
///
/// Falls back to remote-only if the local database is not available
/// (e.g., on web without WASM worker support).
final cachingExerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  try {
    final db = ref.watch(localDatabaseProvider);
    final connectivity = ref.watch(connectivityMonitorProvider);
    final remote = ref.watch(remoteExerciseRepositoryProvider);

    return CachingExerciseRepository(
      remote: remote,
      dao: db.exerciseDao,
      cacheMetadataDao: db.cacheMetadataDao,
      connectivity: connectivity,
    );
  } catch (e) {
    // Database not available (e.g., web without WASM) — fall back to remote only
    return ref.watch(remoteExerciseRepositoryProvider);
  }
});

/// Provides a [CachingWorkoutRepository] that wraps the remote repository
/// with local SQLite caching, cache freshness logic, and offline mutation queuing.
///
/// Falls back to remote-only if the local database is not available.
final cachingWorkoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  try {
    final db = ref.watch(localDatabaseProvider);
    final connectivity = ref.watch(connectivityMonitorProvider);
    final remote = ref.watch(remoteWorkoutRepositoryProvider);
    final dbImpl = db as LocalDatabaseImpl;

    return CachingWorkoutRepository(
      remote: remote,
      dao: db.workoutDao,
      cacheMetadataDao: db.cacheMetadataDao,
      syncQueueDao: db.syncQueueDao,
      connectivity: connectivity,
      database: dbImpl.database,
    );
  } catch (e) {
    // Database not available (e.g., web without WASM) — fall back to remote only
    return ref.watch(remoteWorkoutRepositoryProvider);
  }
});

/// Provides a [CachingProfileRepository] that wraps the remote repository
/// with local SQLite caching, PATCH-semantics offline mutations, and
/// sync-queue integration.
///
/// Falls back to remote-only if the local database is not available.
final cachingProfileRepositoryProvider = Provider<ProfileRepository>((ref) {
  try {
    final db = ref.watch(localDatabaseProvider);
    final connectivity = ref.watch(connectivityMonitorProvider);
    final remote = ref.watch(remoteProfileRepositoryProvider);

    return CachingProfileRepository(
      remote: remote,
      dao: db.profileDao,
      cacheMetadataDao: db.cacheMetadataDao,
      syncQueueDao: db.syncQueueDao,
      connectivity: connectivity,
    );
  } catch (e) {
    // Database not available (e.g., web without WASM) — fall back to remote only
    return ref.watch(remoteProfileRepositoryProvider);
  }
});

/// Provides a [CachingProgressRepository] that wraps the remote repository
/// with local SQLite caching, cache freshness logic, and offline mutation queuing.
///
/// Falls back to remote-only if the local database is not available.
final cachingProgressRepositoryProvider = Provider<ProgressRepository>((ref) {
  try {
    final db = ref.watch(localDatabaseProvider);
    final connectivity = ref.watch(connectivityMonitorProvider);
    final remote = ref.watch(remoteProgressRepositoryProvider);

    return CachingProgressRepository(
      remote: remote,
      dao: db.progressDao,
      cacheMetadataDao: db.cacheMetadataDao,
      syncQueueDao: db.syncQueueDao,
      connectivity: connectivity,
    );
  } catch (e) {
    // Database not available (e.g., web without WASM) — fall back to remote only
    return ref.watch(remoteProgressRepositoryProvider);
  }
});
