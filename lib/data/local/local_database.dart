import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'daos/cache_metadata_dao.dart';
import 'daos/exercise_dao.dart';
import 'daos/profile_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/workout_dao.dart';
import 'daos/workout_history_dao.dart';

/// Abstract interface for the local SQLite database.
///
/// Provides access to DAO objects for each entity type and manages
/// database lifecycle (initialization and cleanup).
abstract class LocalDatabase {
  /// Initializes the database, creating all required tables.
  Future<void> initialize();

  /// DAO for exercise CRUD operations.
  ExerciseDao get exerciseDao;

  /// DAO for workout CRUD operations.
  WorkoutDao get workoutDao;

  /// DAO for user profile CRUD operations.
  ProfileDao get profileDao;

  /// DAO for sync queue operations.
  SyncQueueDao get syncQueueDao;

  /// DAO for workout history CRUD operations.
  WorkoutHistoryDao get workoutHistoryDao;

  /// DAO for cache metadata operations.
  CacheMetadataDao get cacheMetadataDao;

  /// Closes the database connection.
  Future<void> close();
}

/// SQLite implementation of [LocalDatabase].
///
/// Uses the `sqflite` package to manage a local SQLite database for
/// offline caching of exercises, workouts, user profile, workout history,
/// sync queue mutations, and cache metadata.
class LocalDatabaseImpl implements LocalDatabase {
  static const String _databaseName = 'syncrofit.db';
  static const int _databaseVersion = 3;

  Database? _database;

  /// Returns the underlying [Database] instance.
  ///
  /// Throws [StateError] if the database has not been initialized.
  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError(
        'Database not initialized. Call initialize() before accessing the database.',
      );
    }
    return db;
  }

  @override
  Future<void> initialize() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 2 && oldVersion < 3) {
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN first_name TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN last_name TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE user_profile ADD COLUMN username TEXT NOT NULL DEFAULT ''");
      return;
    }

    // Pre-v2 schemas are incompatible and contain cache-only data.
    await db.execute('DROP TABLE IF EXISTS exercises');
    await db.execute('DROP TABLE IF EXISTS workouts');
    await db.execute('DROP TABLE IF EXISTS workout_sessions');
    await db.execute('DROP TABLE IF EXISTS user_profile');
    await db.execute('DROP TABLE IF EXISTS progress_records');
    await db.execute('DROP TABLE IF EXISTS sync_queue');
    await db.execute('DROP TABLE IF EXISTS cache_metadata');
    await _onCreate(db, newVersion);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        username TEXT NOT NULL DEFAULT '',
        muscle_group TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        instructions TEXT NOT NULL,
        equipment TEXT,
        default_duration_seconds INTEGER NOT NULL,
        default_sets INTEGER NOT NULL,
        default_reps INTEGER NOT NULL,
        video_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        day_of_week TEXT,
        estimated_duration_minutes INTEGER NOT NULL,
        exercises TEXT NOT NULL,
        is_generated INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_history (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workout_name TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        total_duration_seconds INTEGER NOT NULL,
        exercises_completed TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        user_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        height_cm REAL NOT NULL,
        weight_kg REAL NOT NULL,
        gender TEXT NOT NULL,
        fitness_goal TEXT NOT NULL,
        fitness_level TEXT NOT NULL,
        workout_preference TEXT NOT NULL,
        availability_days TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE cache_metadata (
        entity_type TEXT PRIMARY KEY,
        last_synced_at TEXT NOT NULL
      )
    ''');
  }

  @override
  ExerciseDao get exerciseDao => ExerciseDao(database);

  @override
  WorkoutDao get workoutDao => WorkoutDao(database);

  @override
  ProfileDao get profileDao => ProfileDao(database);

  @override
  WorkoutHistoryDao get workoutHistoryDao => WorkoutHistoryDao(database);

  @override
  SyncQueueDao get syncQueueDao => SyncQueueDao(database);

  @override
  CacheMetadataDao get cacheMetadataDao => CacheMetadataDao(database);

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
