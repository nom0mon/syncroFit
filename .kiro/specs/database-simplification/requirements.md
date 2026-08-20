# Requirements Document

## Introduction

This document defines the requirements for simplifying the SyncroFit database from 15+ tables down to 5 core tables. The restructuring consolidates redundant tables, embeds exercise data as JSON within workouts, removes unused features (push notifications), and derives progress statistics from workout history instead of storing them separately. The goal is a leaner, easier-to-understand schema that maintains all essential functionality while reducing complexity for both the Laravel backend and the Flutter frontend.

## Glossary

- **Backend**: The Laravel PHP application providing REST API endpoints, using MySQL/SQLite as the database
- **Frontend**: The Flutter mobile application with local SQLite caching and offline support
- **Exercise_Library**: The collection of seeded exercise records available for use in workouts
- **Workout**: A user's workout plan containing a name, day of week, estimated duration, and an embedded list of exercises stored as JSON
- **Generated_Workout**: A workout record produced by the recommendation engine, identified by the `is_generated` flag set to true
- **Workout_History**: A record of a completed workout session including workout name, completion timestamp, duration, and exercises completed
- **Exercise_JSON**: A JSON array embedded in the workouts table that stores exercise details (exercise_id, sets, reps, duration_seconds, order) inline rather than in a separate join table
- **Video_Path**: A local asset path referencing a video file (e.g., `assets/videos/pushups.mp4`) stored on the exercises table, replacing the previous `image_url` field
- **Migration**: A Laravel database migration that applies schema changes (creating/dropping tables, altering columns)
- **DAO**: Data Access Object in the Flutter frontend that handles local SQLite database operations
- **Sync_Queue**: The offline-first queue mechanism in the Flutter app that stores pending API operations for later synchronization

## Requirements

### Requirement 1: Drop Obsolete Database Tables

**User Story:** As a developer, I want to remove unused and redundant database tables, so that the schema is simpler and easier to maintain.

#### Acceptance Criteria

1. WHEN the Migration is executed, THE Backend SHALL drop the `recommendations` table from the database
2. WHEN the Migration is executed, THE Backend SHALL drop the `workout_exercises` table from the database
3. WHEN the Migration is executed, THE Backend SHALL drop the `progress_records` table from the database
4. WHEN the Migration is executed, THE Backend SHALL drop the `device_tokens` table from the database
5. WHEN the Migration is executed, THE Backend SHALL drop the `workout_sessions` table from the database
6. WHEN the Migration is executed, THE Backend SHALL drop the `session_exercises` table from the database
7. THE Migration SHALL include a rollback method that recreates all dropped tables with their original schema

### Requirement 2: Restructure Exercises Table

**User Story:** As a developer, I want to replace the `image_url` column with `video_path` on the exercises table, so that exercises reference local video assets instead of remote images.

#### Acceptance Criteria

1. WHEN the Migration is executed, THE Backend SHALL rename the `image_url` column to `video_path` on the exercises table
2. THE Exercise model SHALL declare `video_path` as a fillable string attribute
3. THE Exercise model SHALL remove the `image_url` attribute from its fillable array
4. THE Exercise model SHALL remove the `workoutExercises` and `sessionExercises` relationships
5. WHEN the ExerciseSeeder runs, THE Backend SHALL populate `video_path` with local asset paths in the format `assets/videos/{exercise_name_snake_case}.mp4`

### Requirement 3: Restructure Workouts Table

**User Story:** As a developer, I want the workouts table to store exercises as an embedded JSON array and include an `is_generated` flag, so that workout plans and recommendation outputs are unified in a single table.

#### Acceptance Criteria

1. WHEN the Migration is executed, THE Backend SHALL create the `workouts` table with columns: id, user_id (foreign key to users), name (string), day_of_week (string, nullable), estimated_duration_minutes (integer, nullable), exercises (JSON), is_generated (boolean, default false), created_at, updated_at
2. THE Workout model SHALL cast the `exercises` column as a JSON array
3. THE Workout model SHALL cast `is_generated` as a boolean
4. THE Workout model SHALL belong to a User
5. WHEN a workout is stored, THE Backend SHALL validate that the `exercises` JSON array contains objects with required fields: exercise_id, sets, reps, duration_seconds, and order
6. WHEN the recommendation engine produces a workout plan, THE Backend SHALL store the result in the workouts table with `is_generated` set to true

### Requirement 4: Create Workout History Table

**User Story:** As a developer, I want a simplified workout_history table to record completed sessions, so that progress statistics can be derived from historical data without a separate progress table.

#### Acceptance Criteria

1. WHEN the Migration is executed, THE Backend SHALL create the `workout_history` table with columns: id, user_id (foreign key to users), workout_name (string), completed_at (timestamp), total_duration_seconds (integer), exercises_completed (JSON), created_at, updated_at
2. THE WorkoutHistory model SHALL cast `exercises_completed` as a JSON array
3. THE WorkoutHistory model SHALL cast `completed_at` as a datetime
4. THE WorkoutHistory model SHALL belong to a User
5. WHEN a workout session is completed, THE Backend SHALL create a workout_history record with the workout name, completion timestamp, total duration, and a JSON array of completed exercises

### Requirement 5: Consolidate Backend Controllers

**User Story:** As a developer, I want to remove redundant controllers and merge recommendation functionality into the workout controller, so that the API surface is cleaner and matches the simplified schema.

#### Acceptance Criteria

1. THE Backend SHALL remove the DeviceTokenController
2. THE Backend SHALL remove the ProgressController
3. THE Backend SHALL remove the WorkoutSessionController
4. THE Backend SHALL remove the RecommendationController
5. THE Backend SHALL provide a WorkoutController with endpoints for: listing workouts, creating workouts, generating workouts via the recommendation engine, and retrieving generated workouts
6. THE Backend SHALL provide a WorkoutHistoryController with endpoints for: recording a completed workout and retrieving workout history for the authenticated user
7. WHEN a client requests progress statistics, THE WorkoutHistoryController SHALL compute summary data (total workouts, total duration, weekly stats) from workout_history records

### Requirement 6: Update API Routes

**User Story:** As a developer, I want the API routes to reflect the simplified controller structure, so that the frontend can integrate with the new endpoints.

#### Acceptance Criteria

1. THE Backend SHALL remove routes for `/device-tokens`, `/sessions/*`, `/progress/*`, and `/recommendations/*`
2. THE Backend SHALL register routes for workouts: GET `/workouts`, POST `/workouts`, POST `/workouts/generate`, GET `/workouts/generated`
3. THE Backend SHALL register routes for workout history: POST `/workout-history`, GET `/workout-history`, GET `/workout-history/stats`
4. THE Backend SHALL keep all workout and workout-history routes protected behind the `auth:sanctum` middleware
5. THE Backend SHALL keep existing auth routes (`/register`, `/login`, `/logout`, `/forgot-password`) unchanged
6. THE Backend SHALL keep existing profile routes (`/profile`) unchanged
7. THE Backend SHALL keep existing exercise routes (`/exercises`, `/exercises/{exercise}`) unchanged

### Requirement 7: Remove Obsolete Backend Models

**User Story:** As a developer, I want to delete model files that no longer correspond to database tables, so that the codebase does not contain dead code.

#### Acceptance Criteria

1. THE Backend SHALL remove the DeviceToken model file
2. THE Backend SHALL remove the ProgressRecord model file
3. THE Backend SHALL remove the Recommendation model file
4. THE Backend SHALL remove the WorkoutExercise model file
5. THE Backend SHALL remove the SessionExercise model file
6. THE Backend SHALL remove the WorkoutSession model file
7. THE User model SHALL remove relationships to DeviceToken, ProgressRecord, Recommendation, and WorkoutSession
8. THE User model SHALL add a relationship to WorkoutHistory

### Requirement 8: Update Flutter Exercise Model and UI

**User Story:** As a user, I want to see exercise demonstration videos instead of static images, so that I can better understand how to perform each exercise.

#### Acceptance Criteria

1. THE Frontend Exercise model SHALL replace the `imagePlaceholder` field with a `videoPath` string field
2. THE Frontend Exercise model SHALL serialize and deserialize the `videoPath` field when converting to and from JSON
3. WHEN the exercise detail screen displays an exercise, THE Frontend SHALL render a video player component using the `videoPath` value
4. IF the `videoPath` value is null or the asset is unavailable, THEN THE Frontend SHALL display a placeholder icon instead of the video player

### Requirement 9: Update Flutter Workout Model

**User Story:** As a developer, I want the Flutter workout model to match the new backend schema with embedded exercises and the is_generated flag, so that data can be synchronized correctly.

#### Acceptance Criteria

1. THE Frontend Workout model SHALL contain fields: id, userId, name, dayOfWeek, estimatedDurationMinutes, exercises (list of exercise objects), isGenerated (boolean), createdAt, updatedAt
2. THE Frontend Workout model SHALL serialize the exercises field as a JSON array
3. THE Frontend Workout model SHALL deserialize exercises from a JSON array into a list of typed exercise objects containing: exerciseId, sets, reps, durationSeconds, and order
4. WHEN a workout is marked as generated, THE Frontend SHALL display a visual indicator distinguishing it from user-created workouts

### Requirement 10: Create Flutter WorkoutHistory Model

**User Story:** As a developer, I want a WorkoutHistory model in the Flutter app that matches the new backend table, so that completed workout data can be stored locally and synced.

#### Acceptance Criteria

1. THE Frontend WorkoutHistory model SHALL contain fields: id, userId, workoutName, completedAt (DateTime), totalDurationSeconds (int), exercisesCompleted (list of JSON objects), createdAt, updatedAt
2. THE Frontend WorkoutHistory model SHALL serialize and deserialize to and from JSON for both API communication and local SQLite storage
3. THE Frontend WorkoutHistory model SHALL replace the existing WorkoutSession model in all references

### Requirement 11: Update Flutter Local Database and DAOs

**User Story:** As a developer, I want the local SQLite schema and DAOs to match the simplified backend structure, so that offline caching works correctly with the new tables.

#### Acceptance Criteria

1. WHEN the local database is initialized, THE Frontend SHALL create tables matching the simplified schema: exercises (with video_path), workouts (with exercises JSON and is_generated), workout_history
2. THE Frontend SHALL remove the `progress_dao.dart` file and its references
3. THE Frontend SHALL update the exercise DAO to handle the `video_path` column instead of `image_url`
4. THE Frontend SHALL update the workout DAO to read and write the embedded exercises JSON and the `is_generated` flag
5. THE Frontend SHALL create a workout history DAO with methods for inserting records and querying history by user and date range
6. WHEN the local database schema version changes, THE Frontend SHALL run a migration that drops old tables and recreates them with the new schema

### Requirement 12: Update Flutter Caching Repositories

**User Story:** As a developer, I want the caching repositories to use the new DAOs and models, so that the offline-first architecture continues to function with the simplified schema.

#### Acceptance Criteria

1. THE Frontend caching repositories SHALL use the updated Workout model with embedded exercises
2. THE Frontend caching repositories SHALL use the WorkoutHistory model instead of WorkoutSession
3. THE Frontend SHALL remove any caching logic related to progress_records
4. THE Frontend Sync_Queue SHALL handle synchronization of workout_history records to the backend

### Requirement 13: Remove Obsolete Frontend Code

**User Story:** As a developer, I want to remove frontend code that references deleted tables and removed features, so that the codebase has no dead code paths.

#### Acceptance Criteria

1. THE Frontend SHALL remove the progress feature folder or refactor it to derive stats from workout_history
2. THE Frontend SHALL remove any notification-related code that depended on device_tokens
3. THE Frontend SHALL remove the WorkoutSession model file
4. THE Frontend SHALL update all providers and state management that referenced removed models to use the new Workout and WorkoutHistory models
