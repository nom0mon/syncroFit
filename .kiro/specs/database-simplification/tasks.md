# Implementation Plan: Database Simplification

## Overview

This plan consolidates the SyncroFit database from 15+ tables to 5 core tables by implementing backend migrations, model refactoring, controller consolidation, route updates, and corresponding Flutter frontend changes. The implementation proceeds backend-first (schema → models → controllers → routes) then frontend (models → DAOs → repositories → cleanup).

## Tasks

- [x] 1. Backend database migration and schema changes
  - [x] 1.1 Create the Laravel migration to drop obsolete tables and restructure schema
    - Create a new migration file `database/migrations/xxxx_xx_xx_simplify_database_schema.php`
    - In the `up()` method: drop tables `session_exercises`, `workout_sessions`, `workout_exercises`, `recommendations`, `progress_records`, `device_tokens` in dependency order
    - Rename `exercises.image_url` column to `video_path`
    - Drop and recreate the `workouts` table with columns: id, user_id (FK to users), name (string), day_of_week (string nullable), estimated_duration_minutes (integer nullable), exercises (JSON), is_generated (boolean default false), timestamps
    - Create `workout_history` table with columns: id, user_id (FK to users), workout_name (string), completed_at (timestamp), total_duration_seconds (integer), exercises_completed (JSON), timestamps
    - Implement `down()` method that reverses all changes (recreates dropped tables with original schema, renames video_path back to image_url)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 2.1, 3.1, 4.1_

  - [x] 1.2 Write property test for exercise name to video_path format conversion
    - **Property 1: Exercise name to video_path format conversion**
    - Using Eris, generate random valid exercise name strings and verify the video_path generation produces `assets/videos/{snake_case_name}.mp4`
    - **Validates: Requirements 2.5**

  - [x] 1.3 Update the ExerciseSeeder to populate video_path
    - Modify `database/seeders/ExerciseSeeder.php` to set `video_path` to `assets/videos/{exercise_name_snake_case}.mp4` for each exercise
    - Remove any references to `image_url`
    - _Requirements: 2.5_

- [x] 2. Backend model refactoring
  - [x] 2.1 Remove obsolete model files
    - Delete model files: `DeviceToken.php`, `ProgressRecord.php`, `Recommendation.php`, `WorkoutExercise.php`, `SessionExercise.php`, `WorkoutSession.php`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

  - [x] 2.2 Update the Exercise model
    - Replace `image_url` with `video_path` in the fillable array
    - Remove `workoutExercises` and `sessionExercises` relationship methods
    - Ensure `instructions` cast remains as array
    - _Requirements: 2.2, 2.3, 2.4_

  - [x] 2.3 Rewrite the Workout model
    - Set fillable: user_id, name, day_of_week, estimated_duration_minutes, exercises, is_generated
    - Add casts: `exercises` → array, `is_generated` → boolean
    - Add `user()` belongsTo relationship
    - _Requirements: 3.2, 3.3, 3.4_

  - [x] 2.4 Create the WorkoutHistory model
    - Create `app/Models/WorkoutHistory.php`
    - Set fillable: user_id, workout_name, completed_at, total_duration_seconds, exercises_completed
    - Add casts: `exercises_completed` → array, `completed_at` → datetime
    - Add `user()` belongsTo relationship
    - _Requirements: 4.2, 4.3, 4.4_

  - [x] 2.5 Update the User model relationships
    - Remove relationships to DeviceToken, ProgressRecord, Recommendation, WorkoutSession
    - Add `workoutHistory()` hasMany relationship to WorkoutHistory
    - Ensure `workouts()` relationship remains
    - _Requirements: 7.7, 7.8_

  - [x] 2.6 Write property test for Workout exercises JSON round-trip
    - **Property 2: Workout exercises JSON round-trip (Backend)**
    - Using Eris, generate arrays of exercise objects with exercise_id, sets, reps, duration_seconds, order, store in Workout model and verify identical array on read-back
    - **Validates: Requirements 3.2**

  - [x] 2.7 Write property test for WorkoutHistory exercises_completed JSON round-trip
    - **Property 4: WorkoutHistory exercises_completed JSON round-trip (Backend)**
    - Using Eris, generate arrays of exercise completion objects, store in WorkoutHistory model, verify identical on read-back
    - **Validates: Requirements 4.2**

- [x] 3. Checkpoint - Backend models verified
  - Ensure all tests pass, ask the user if questions arise.

- [-] 4. Backend controllers and routes
  - [x] 4.1 Create the WorkoutController
    - Create `app/Http/Controllers/WorkoutController.php` with methods: index, store, generate, generated
    - `index`: list authenticated user's workouts, optionally filter by is_generated
    - `store`: validate exercises JSON (require exercise_id, sets, reps, duration_seconds, order for each item), create workout
    - `generate`: call RecommendationEngine and store results with is_generated=true
    - `generated`: list workouts where is_generated=true for the authenticated user
    - _Requirements: 3.5, 3.6, 5.5_

  - [x] 4.2 Write property test for workout exercises JSON validation
    - **Property 3: Workout exercises JSON validation**
    - Using Eris, generate JSON arrays with and without required fields. Verify validation rejects missing fields and accepts complete objects.
    - **Validates: Requirements 3.5**

  - [x] 4.3 Create the WorkoutHistoryController
    - Create `app/Http/Controllers/WorkoutHistoryController.php` with methods: store, index, stats
    - `store`: validate input and create a workout_history record with workout_name, completed_at, total_duration_seconds, exercises_completed
    - `index`: list history for authenticated user
    - `stats`: compute total_workouts (count), total_duration (sum of total_duration_seconds), weekly_stats (grouped by ISO week) from workout_history
    - _Requirements: 4.5, 5.6, 5.7_

  - [x] 4.4 Write property test for progress statistics computation
    - **Property 5: Progress statistics computation correctness**
    - Using Eris, generate sets of workout_history records and verify total_workouts = count, total_duration = sum, weekly grouping is correct by ISO week
    - **Validates: Requirements 5.7**

  - [x] 4.5 Remove obsolete controllers
    - Delete: `DeviceTokenController.php`, `ProgressController.php`, `WorkoutSessionController.php`, `RecommendationController.php`
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 4.6 Update API routes
    - Remove routes for `/device-tokens`, `/sessions/*`, `/progress/*`, `/recommendations/*`
    - Register workout routes: GET `/workouts`, POST `/workouts`, POST `/workouts/generate`, GET `/workouts/generated`
    - Register workout history routes: POST `/workout-history`, GET `/workout-history`, GET `/workout-history/stats`
    - Ensure all new routes are protected by `auth:sanctum` middleware
    - Verify existing auth, profile, and exercise routes remain unchanged
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [x] 4.7 Update the RecommendationEngine service
    - Modify `RecommendationEngine::generate()` to store generated workouts in the `workouts` table with `is_generated = true`
    - Replace any references to WorkoutSession/SessionExercise with workout_history for adaptation factor computation
    - _Requirements: 3.6_

- [x] 5. Checkpoint - Backend complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Frontend model updates
  - [x] 6.1 Update the Flutter Exercise model
    - Replace `imagePlaceholder` field with `videoPath` (String?)
    - Update `toJson()` and `fromJson()` to serialize/deserialize `video_path` ↔ `videoPath`
    - _Requirements: 8.1, 8.2_

  - [x] 6.2 Update the Flutter Workout model
    - Ensure fields: id, userId, name, dayOfWeek, estimatedDurationMinutes, exercises (List<WorkoutExercise>), isGenerated (bool), createdAt, updatedAt
    - Implement `toJson()` serializing exercises as JSON array
    - Implement `fromJson()` deserializing exercises into typed WorkoutExercise objects with exerciseId, sets, reps, durationSeconds, order
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 6.3 Create the Flutter WorkoutHistory model
    - Create `lib/core/models/workout_history.dart`
    - Fields: id, userId, workoutName, completedAt (DateTime), totalDurationSeconds (int), exercisesCompleted (List<Map<String, dynamic>>), createdAt, updatedAt
    - Implement `toJson()` and `fromJson()` for API and local SQLite serialization
    - _Requirements: 10.1, 10.2_

  - [x] 6.4 Write property test for Frontend Workout model serialization round-trip
    - **Property 6: Frontend Workout model and DAO serialization round-trip**
    - Using glados, generate valid Workout objects and verify toJson() → fromJson() produces equivalent objects
    - **Validates: Requirements 9.2, 9.3, 11.4**

  - [x] 6.5 Write property test for Frontend WorkoutHistory model serialization round-trip
    - **Property 7: Frontend WorkoutHistory model serialization round-trip**
    - Using glados, generate valid WorkoutHistory objects and verify toJson() → fromJson() equivalence
    - **Validates: Requirements 10.2**

- [x] 7. Frontend local database and DAOs
  - [x] 7.1 Update the local SQLite database schema to v2
    - Increment the database version number
    - Implement destructive migration (drop and recreate all tables)
    - Create tables: exercises (with video_path), workouts (with exercises JSON, is_generated, user_id, day_of_week), workout_history, user_profile, sync_queue, cache_metadata
    - _Requirements: 11.1, 11.6_

  - [x] 7.2 Update the Exercise DAO
    - Handle `video_path` column instead of `image_url` / `image_placeholder`
    - Update insert, query, and mapping methods
    - _Requirements: 11.3_

  - [x] 7.3 Update the Workout DAO
    - Handle `is_generated` column (stored as INTEGER 0/1)
    - Handle `user_id` and `day_of_week` columns
    - Read/write embedded exercises JSON
    - _Requirements: 11.4_

  - [x] 7.4 Create the WorkoutHistory DAO
    - Create `lib/core/database/daos/workout_history_dao.dart`
    - Implement: `insertRecord(WorkoutHistory)`, `getByUser(String userId)`, `getByDateRange(String userId, DateTime start, DateTime end)`, `deleteAll()`
    - _Requirements: 11.5_

  - [x] 7.5 Remove the progress DAO
    - Delete `progress_dao.dart` and remove all references
    - _Requirements: 11.2_

  - [x] 7.6 Write property test for Frontend Exercise DAO video_path round-trip
    - **Property 8: Frontend Exercise DAO video_path round-trip**
    - Using glados, generate Exercise objects with non-null videoPath, insert and read back, verify videoPath is identical
    - **Validates: Requirements 8.2, 11.3**

  - [x] 7.7 Write property test for WorkoutHistory DAO date range query correctness
    - **Property 9: WorkoutHistory DAO date range query correctness**
    - Using glados, generate sets of WorkoutHistory records with various timestamps and date ranges, verify query returns exactly records within range
    - **Validates: Requirements 11.5**

- [x] 8. Checkpoint - Frontend models and DAOs verified
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Frontend repositories, sync, and UI integration
  - [x] 9.1 Update caching repositories
    - Update `CachingWorkoutRepository` to use the new Workout model with embedded exercises and isGenerated
    - Create `CachingWorkoutHistoryRepository` to replace any progress caching logic
    - Remove caching logic related to progress_records
    - _Requirements: 12.1, 12.2, 12.3_

  - [x] 9.2 Update the SyncQueue for workout_history
    - Add `workout_history` as a supported entity type in the sync engine
    - Ensure offline-created workout_history records are queued and synced when connectivity resumes
    - _Requirements: 12.4_

  - [x] 9.3 Update the exercise detail screen for video playback
    - Replace image widget with a video player component using `videoPath`
    - Add fallback: if `videoPath` is null or asset unavailable, show a placeholder icon
    - _Requirements: 8.3, 8.4_

  - [x] 9.4 Add visual indicator for generated workouts
    - When `isGenerated` is true on a workout, display a badge or label distinguishing it from user-created workouts
    - _Requirements: 9.4_

- [x] 10. Frontend cleanup - remove obsolete code
  - [x] 10.1 Remove obsolete frontend files and references
    - Delete the WorkoutSession model file
    - Remove or refactor the progress feature folder to derive stats from WorkoutHistory
    - Remove notification-related code that depended on device_tokens
    - Update all providers and state management referencing removed models to use Workout and WorkoutHistory
    - _Requirements: 13.1, 13.2, 13.3, 13.4_

  - [x] 10.2 Replace WorkoutSession references with WorkoutHistory
    - Find all imports/usages of WorkoutSession and replace with WorkoutHistory
    - Update any mock files referencing removed repositories
    - _Requirements: 10.3_

- [x] 11. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Backend uses PHP/Laravel with Eris for property-based testing
- Frontend uses Dart/Flutter with glados for property-based testing
- The Flutter local database uses a destructive migration since the cache is ephemeral and will be repopulated from the API

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "2.2", "2.3", "2.4", "2.5"] },
    { "id": 2, "tasks": ["2.6", "2.7", "4.5"] },
    { "id": 3, "tasks": ["4.1", "4.3", "4.7"] },
    { "id": 4, "tasks": ["4.2", "4.4", "4.6"] },
    { "id": 5, "tasks": ["6.1", "6.2", "6.3"] },
    { "id": 6, "tasks": ["6.4", "6.5", "7.1"] },
    { "id": 7, "tasks": ["7.2", "7.3", "7.4", "7.5"] },
    { "id": 8, "tasks": ["7.6", "7.7"] },
    { "id": 9, "tasks": ["9.1", "9.2", "9.3", "9.4"] },
    { "id": 10, "tasks": ["10.1", "10.2"] }
  ]
}
```
