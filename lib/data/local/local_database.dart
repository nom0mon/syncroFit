import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'daos/cache_metadata_dao.dart';
import 'daos/exercise_dao.dart';
import 'daos/profile_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/workout_dao.dart';

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

  /// DAO for progress record CRUD operations.
  ProgressDao get progressDao;

  /// DAO for sync queue operations.
  SyncQueueDao get syncQueueDao;

  /// DAO for cache metadata operations.
  CacheMetadataDao get cacheMetadataDao;

  /// Closes the database connection.
  Future<void> close();
}

/// SQLite implementation of [LocalDatabase].
///
/// Uses the `sqflite` package to manage a local SQLite database for
/// offline caching of exercises, workouts, user profile, progress records,
/// sync queue mutations, and cache metadata.
class LocalDatabaseImpl implements LocalDatabase {
  static const String _databaseName = 'syncrofit.db';
  static const int _databaseVersion = 1;

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
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        instructions TEXT NOT NULL,
        equipment TEXT,
        default_duration_seconds INTEGER NOT NULL,
        default_sets INTEGER NOT NULL,
        default_reps INTEGER NOT NULL,
        image_url TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        estimated_duration_minutes INTEGER NOT NULL,
        day_of_week TEXT,
        exercises TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sessions (
        id TEXT PRIMARY KEY,
        workout_id TEXT NOT NULL,
        workout_name TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        total_duration_seconds INTEGER NOT NULL,
        exercises_completed INTEGER NOT NULL,
        exercises TEXT NOT NULL
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
      CREATE TABLE progress_records (
        id TEXT PRIMARY KEY,
        recorded_at TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        bmi REAL NOT NULL,
        workouts_completed INTEGER NOT NULL
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
  ProgressDao get progressDao => ProgressDao(database);

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
