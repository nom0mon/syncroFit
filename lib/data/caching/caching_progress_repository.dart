import '../../core/network/connectivity_monitor.dart';
import '../../data/local/daos/cache_metadata_dao.dart';
import '../../data/local/daos/progress_dao.dart';
import '../../data/local/daos/sync_queue_dao.dart';
import '../../data/repositories/progress_repository.dart';
import '../../shared/models/models.dart';

/// Caching decorator for [ProgressRepository] that adds offline persistence
/// and sync-queue integration.
///
/// Online behaviour:
/// - If cache is fresh (< 15 minutes old), serves from local DAO.
/// - If cache is stale, fetches from the remote backend, persists results
///   to the local DAO, and updates cache metadata.
///
/// Offline behaviour:
/// - Serves data from the local DAO.
/// - Queues any mutations to the [SyncQueueDao] for later synchronisation.
class CachingProgressRepository implements ProgressRepository {
  final ProgressRepository _remote;
  final ProgressDao _dao;
  final CacheMetadataDao _cacheMetadataDao;
  // ignore: unused_field -- retained for mutation queuing pattern consistency
  final SyncQueueDao _syncQueueDao;
  final ConnectivityMonitor _connectivity;

  /// Cache freshness threshold — 15 minutes.
  static const Duration _cacheMaxAge = Duration(minutes: 15);

  static const String _entityType = 'progress';

  CachingProgressRepository({
    required ProgressRepository remote,
    required ProgressDao dao,
    required CacheMetadataDao cacheMetadataDao,
    required SyncQueueDao syncQueueDao,
    required ConnectivityMonitor connectivity,
  })  : _remote = remote,
        _dao = dao,
        _cacheMetadataDao = cacheMetadataDao,
        _syncQueueDao = syncQueueDao,
        _connectivity = connectivity;

  @override
  Future<Result<List<ProgressRecord>, AppError>> getRecords() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        final cached = await _dao.getAll();
        return Success(cached);
      }

      final result = await _remote.getRecords();
      if (result is Success<List<ProgressRecord>, AppError>) {
        await _dao.upsertAll(result.value);
        await _cacheMetadataDao.updateLastSynced(
          _entityType,
          DateTime.now(),
        );
      }
      return result;
    }

    // Offline: serve from local DAO.
    final cached = await _dao.getAll();
    return Success(cached);
  }

  @override
  Future<Result<Map<String, int>, AppError>> getWeeklyStats() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        // Compute weekly stats from cached progress records.
        return Success(_computeWeeklyStatsFromRecords(await _dao.getAll()));
      }

      final result = await _remote.getWeeklyStats();
      return result;
    }

    // Offline: compute from cached progress records.
    final cached = await _dao.getAll();
    return Success(_computeWeeklyStatsFromRecords(cached));
  }

  @override
  Future<Result<ProgressSummary, AppError>> getSummary() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      if (await _isCacheFresh()) {
        // Compute summary from cached progress records.
        return Success(_computeSummaryFromRecords(await _dao.getAll()));
      }

      final result = await _remote.getSummary();
      return result;
    }

    // Offline: compute from cached progress records.
    final cached = await _dao.getAll();
    return Success(_computeSummaryFromRecords(cached));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` if the cache was synced less than [_cacheMaxAge] ago.
  Future<bool> _isCacheFresh() async {
    final lastSynced = await _cacheMetadataDao.getLastSynced(_entityType);
    if (lastSynced == null) return false;
    return DateTime.now().difference(lastSynced) < _cacheMaxAge;
  }

  /// Computes weekly stats (workouts completed per day name) from cached
  /// progress records by looking at the current week.
  Map<String, int> _computeWeeklyStatsFromRecords(
    List<ProgressRecord> records,
  ) {
    final now = DateTime.now();
    // Start of the current week (Monday).
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDate =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final stats = <String, int>{};
    for (final dayName in dayNames) {
      stats[dayName] = 0;
    }

    for (final record in records) {
      if (record.date.isAfter(startDate) ||
          _isSameDay(record.date, startDate)) {
        final dayIndex = record.date.weekday - 1; // 0=Mon, 6=Sun
        if (dayIndex >= 0 && dayIndex < 7) {
          stats[dayNames[dayIndex]] =
              (stats[dayNames[dayIndex]] ?? 0) + record.workoutsCompleted;
        }
      }
    }

    return stats;
  }

  /// Computes a [ProgressSummary] from cached progress records.
  ProgressSummary _computeSummaryFromRecords(List<ProgressRecord> records) {
    if (records.isEmpty) {
      return const ProgressSummary(
        totalWorkouts: 0,
        currentStreak: 0,
        longestStreak: 0,
        currentWeightKg: 0.0,
      );
    }

    // Sort by date descending for streak calculation.
    final sorted = List<ProgressRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    final totalWorkouts =
        records.fold<int>(0, (sum, r) => sum + r.workoutsCompleted);
    final currentWeightKg = sorted.first.weightKg;

    // Calculate streaks based on consecutive days with workouts > 0.
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].workoutsCompleted > 0) {
        tempStreak++;
        if (i == 0) {
          currentStreak = tempStreak;
        }
      } else {
        if (i == 0) {
          currentStreak = 0;
        }
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
        tempStreak = 0;
      }
    }
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }
    if (currentStreak == 0 && sorted.first.workoutsCompleted > 0) {
      // Re-calculate current streak from the most recent consecutive records.
      currentStreak = 0;
      for (final record in sorted) {
        if (record.workoutsCompleted > 0) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    return ProgressSummary(
      totalWorkouts: totalWorkouts,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      currentWeightKg: currentWeightKg,
    );
  }

  /// Checks if two dates represent the same calendar day.
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
