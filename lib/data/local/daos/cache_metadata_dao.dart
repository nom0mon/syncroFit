import 'package:sqflite/sqflite.dart';

import '../../../shared/models/cache_metadata.dart';

/// Data Access Object for cache metadata in the local SQLite database.
///
/// Tracks the last sync timestamp for each entity type, enabling the
/// caching layer to determine whether cached data is stale.
class CacheMetadataDao {
  final Database _database;

  CacheMetadataDao(this._database);

  static const String _table = 'cache_metadata';

  /// Retrieves the last synced timestamp for a given entity type.
  ///
  /// Returns `null` if no sync metadata exists for the [entityType].
  Future<DateTime?> getLastSynced(String entityType) async {
    final rows = await _database.query(
      _table,
      where: 'entity_type = ?',
      whereArgs: [entityType],
    );
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['last_synced_at'] as String);
  }

  /// Updates the last synced timestamp for a given entity type.
  ///
  /// Creates a new record if one doesn't exist, or replaces the existing one.
  Future<void> updateLastSynced(String entityType, DateTime timestamp) async {
    final metadata = CacheMetadata(
      entityType: entityType,
      lastSyncedAt: timestamp,
    );
    await _database.insert(
      _table,
      metadata.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
