# Implementation Plan: SynchroFit Backend Integration

## Overview

This plan implements the SynchroFit backend (Laravel 12 + MySQL 8 + Sanctum) and wires it to the existing Flutter frontend. The approach is vertical-slice: each API feature is built in Laravel, then the corresponding Flutter screen is connected via real HTTP-backed repository implementations that replace the existing mocks. The Flutter app's architecture (abstract repositories, Riverpod providers, GoRouter) remains intact — only the data layer is extended.

## Tasks

- [x] 1. Laravel project scaffolding and database migrations
  - [x] 1.1 Initialize Laravel 12 project with Sanctum and configure MySQL 8
    - Create the Laravel project in a `backend/` directory at the repository root
    - Install and configure Laravel Sanctum for API token authentication
    - Configure `.env` for MySQL 8 connection, set API middleware
    - Add a global exception handler that wraps all responses in the `{"success", "data", "message", "errors"}` envelope
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

  - [x] 1.2 Create database migrations for all tables
    - Write migrations for: profiles, exercises, recommendations, workouts, workout_exercises, workout_sessions, session_exercises, progress_records, device_tokens
    - Ensure parent tables migrate before child tables; add foreign key constraints and indexes on FK columns plus query columns (exercises.muscle_group, exercises.difficulty, workout_sessions.completed_at, progress_records.recorded_at)
    - Handle existing users table by adding application-specific columns via alter migration
    - _Requirements: 13.1, 13.2, 13.4_

  - [x] 1.3 Create Eloquent models with relationships
    - Define models: User, Profile, Exercise, Recommendation, Workout, WorkoutExercise, WorkoutSession, SessionExercise, ProgressRecord, DeviceToken
    - Set up all relationships (hasOne, hasMany, belongsTo) as defined in the design
    - Add enum casts for status fields, JSON casts for array/json columns
    - _Requirements: 13.1, 13.2_

  - [x] 1.4 Create exercise library seed data
    - Write a seeder with at least 30 exercises covering all muscle groups (≥2 per group), equipment types (≥2 per type), and difficulty levels (≥5 per level)
    - Include name, description, instructions, muscle_group, equipment, difficulty, default_sets, default_reps, default_duration_seconds
    - _Requirements: 13.3_

- [x] 2. Authentication API (Register, Login, Forgot Password, Logout)
  - [x] 2.1 Implement RegisterController with FormRequest validation
    - Create `RegisterRequest` validating name (1–50 chars), email (valid, unique, ≤254 chars), password (8–128 chars)
    - Create user, issue Sanctum token, return in standard envelope with user + token in `data`
    - Return 422 with field-specific errors for invalid/duplicate data
    - _Requirements: 1.1, 1.2, 1.3, 12.1, 12.2_

  - [x] 2.2 Implement LoginController with FormRequest validation
    - Create `LoginRequest` validating email format and password ≥8 chars
    - Authenticate credentials, issue Sanctum token on success
    - Return generic 401 `"Invalid email or password"` for bad credentials (no enumeration)
    - Return 422 for invalid input format
    - _Requirements: 2.1, 2.2, 2.3, 12.1, 12.2_

  - [x] 2.3 Implement ForgotPasswordController with rate limiting
    - Create `ForgotPasswordRequest` validating email format
    - Use Laravel's Password broker to send reset link (60-min expiry)
    - Return identical 200 response regardless of whether email exists (anti-enumeration)
    - Apply rate limiting: 5 requests per email per 15 minutes, return 429 when exceeded
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x] 2.4 Implement LogoutController
    - Revoke current Sanctum token on POST /api/logout
    - Return 200 on success, 401 if token invalid/missing
    - _Requirements: 4.1, 4.5_

  - [x] 2.5 Write feature tests for authentication endpoints
    - Test register happy path, duplicate email (422), invalid fields (422)
    - Test login happy path, invalid credentials (401), invalid format (422)
    - Test forgot-password happy path, anti-enumeration, rate limiting (429)
    - Test logout happy path, unauthenticated (401)
    - _Requirements: 14.1, 14.2, 14.3, 14.5_

- [x] 3. Profile CRUD API
  - [x] 3.1 Implement ProfileController with store/show/update actions
    - Create `StoreProfileRequest` and `UpdateProfileRequest` with validation for all fields (age 13–120, height_cm 50–300, weight_kg 20–500, enum values, availability_days array)
    - Compute BMI on create and on update when height/weight changes: `weight_kg / (height_cm / 100)^2` rounded to 2 decimals
    - Return 409 if profile already exists on store, 404 if no profile on show
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [x] 3.2 Write feature tests for profile endpoints
    - Test create, show, update happy paths
    - Test duplicate profile (409), missing profile (404), validation failures (422)
    - Test BMI computation correctness for various inputs
    - _Requirements: 14.1, 14.2, 14.3_

  - [x] 3.3 Write property test for BMI computation
    - **Property 8: BMI Computation Correctness**
    - Generate random valid height_cm (50–300) and weight_kg (20–500), verify computed BMI equals `weight_kg / (height_cm / 100)^2` rounded to 2 decimals
    - **Validates: Requirements 6.1, 6.5**

- [x] 4. Exercise Library API
  - [x] 4.1 Implement ExerciseController with index and show actions
    - Paginate exercises sorted alphabetically by name, default page size 20
    - Support filter parameters: muscle_group, equipment, difficulty (ignore invalid enum values)
    - Return pagination metadata: current_page, total_pages, total_count
    - Return 404 for non-existent exercise ID, treat page < 1 as page 1
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

  - [x] 4.2 Write feature tests for exercise endpoints
    - Test listing with pagination metadata, filtering by each parameter, combined filters
    - Test single exercise detail, not found (404), page boundary edge cases
    - _Requirements: 14.1, 14.2_

- [x] 5. Checkpoint - Backend core APIs
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Recommendation Engine
  - [x] 6.1 Implement RecommendationEngine service
    - Create `app/Services/RecommendationEngine.php`
    - Filter exercises by user's workout_preference and fitness_level
    - Apply volume rules by goal (lose_weight: 12–20 reps, build_muscle: 6–12 reps, stay_fit: 8–15 reps, increase_stamina: 15–20 reps)
    - Apply volume rules by level (beginner: 2–3 sets, intermediate: 3–4 sets, advanced: 4–5 sets)
    - Schedule one workout per availability_day with muscle group rotation
    - Each workout: 4–8 exercises, rest periods 30–120s
    - _Requirements: 8.1, 8.7_

  - [x] 6.2 Implement adaptation logic in RecommendationEngine
    - When user has ≥2 weeks history: increase volume 5–10% if ≥80% completion, decrease 5–10% if ≥50% skip rate
    - For users with no history, use baseline volume without adaptation
    - _Requirements: 8.3, 8.5_

  - [x] 6.3 Implement RecommendationController
    - POST /api/recommendations/generate — invoke engine, store plan, return weekly plan
    - GET /api/recommendations/current — return most recent recommendation with workouts and exercises
    - Return 422 if profile is incomplete (missing goal or fitness_level)
    - Ensure generation completes within 5 seconds
    - _Requirements: 8.1, 8.2, 8.4, 8.6_

  - [x] 6.4 Write unit tests for RecommendationEngine
    - Test generation for all fitness levels × goals combinations
    - Test adaptation: high completion increases volume, high skip decreases volume
    - Test missing profile returns validation error
    - Test baseline generation with no history
    - _Requirements: 14.4_

  - [x] 6.5 Write property test for plan structure invariants
    - **Property 11: Recommendation Plan Structure Invariants**
    - For random valid profiles, verify: one workout per availability day, 4–8 exercises per workout, sets in 2–5, reps in 5–20, rest_seconds in 30–120
    - **Validates: Requirements 8.1**

  - [x] 6.6 Write property test for recommendation differentiation
    - **Property 13: Recommendation Differentiation by Goal and Level**
    - For pairs of profiles differing only in goal OR only in fitness_level, verify generated plans differ in at least one aspect (exercise selection, rep range, set range, or rest range)
    - **Validates: Requirements 8.7**

- [x] 7. Workout Session Tracking API
  - [x] 7.1 Implement WorkoutSessionController with state machine
    - POST /api/sessions — create session (reject if active session exists)
    - PATCH /api/sessions/{id}/pause — pause active session
    - PATCH /api/sessions/{id}/resume — resume paused session
    - PATCH /api/sessions/{id}/skip-exercise — mark exercise as skipped
    - PATCH /api/sessions/{id}/complete — calculate duration (excluding paused time), record exercise completion data
    - Validate state transitions: reject invalid transitions with error describing current state
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

  - [x] 7.2 Create or update ProgressRecord on workout completion
    - On session complete: create/update ProgressRecord for the date, increment workouts_completed
    - Preserve existing weight_kg and bmi values
    - _Requirements: 10.5_

  - [x] 7.3 Write feature tests for workout session endpoints
    - Test full lifecycle: start → pause → resume → complete
    - Test duplicate active session rejection (409)
    - Test invalid state transitions
    - Test skip exercise, duration calculation excluding paused time
    - _Requirements: 14.1, 14.2_

  - [x] 7.4 Write property test for duration excluding paused time
    - **Property 16: Workout Duration Excludes Paused Time**
    - Generate random sequences of start/pause/resume/complete timestamps, verify total_duration_seconds equals elapsed time minus sum of paused intervals
    - **Validates: Requirements 9.7**

  - [x] 7.5 Write property test for invalid state transitions
    - **Property 15: Workout Session Invalid Transitions Rejected**
    - Generate random session states and random transition attempts, verify invalid transitions are rejected
    - **Validates: Requirements 9.5**

- [x] 8. Progress Tracking API
  - [x] 8.1 Implement ProgressController
    - GET /api/progress/summary — return total workouts, current streak, longest streak, latest weight
    - GET /api/progress/history — return all ProgressRecords ordered by date ascending
    - GET /api/progress/weekly-stats — return workouts completed per day for current week (Mon–Sun)
    - Handle no-data case: return zeros and null weight
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [x] 8.2 Write feature tests for progress endpoints
    - Test summary with data, summary with no data
    - Test history ordering, weekly stats accuracy
    - _Requirements: 14.1, 14.2_

  - [x] 8.3 Write property test for streak calculation
    - **Property 17: Streak Calculation Correctness**
    - Generate random sets of completion dates, verify current_streak equals consecutive days ending today/yesterday, longest_streak equals max consecutive run
    - **Validates: Requirements 10.1**

- [x] 9. Checkpoint - Backend feature APIs complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Flutter ApiClient and token management
  - [x] 10.1 Create ApiClient with Dio, token attachment, and error mapping
    - Create `lib/core/network/api_client.dart` using Dio HTTP client
    - Create `lib/core/network/api_config.dart` with base URL and 30s timeout
    - Create `lib/core/network/token_storage.dart` wrapping flutter_secure_storage
    - Attach Bearer token from TokenStorage on every request (when available)
    - Parse `{"success", "data", "message", "errors"}` envelope into Result type
    - Map 401 → clear token + navigate to login; 422 → ValidationError; timeout → NetworkError; other errors → AppError with status code and message
    - Expose per-request loading state via Riverpod provider
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [x] 10.2 Add JSON serialization to existing Flutter models
    - Add `fromJson` factory and `toJson` method to: User, UserProfile, Exercise, Workout, WorkoutExercise, WorkoutSession, CompletedExercise, ProgressRecord, NotificationItem
    - Keep existing model structure unchanged, only add serialization
    - _Requirements: 5.2, 6.7_

  - [x] 10.3 Write property tests for ApiClient response parsing
    - **Property 1: API Response Parsing Round-Trip**
    - Generate random valid success/error envelope JSON, verify parsing produces correct Result types
    - Use `glados` package for property-based testing
    - **Validates: Requirements 5.2, 12.1, 12.2**

  - [x] 10.4 Write property test for token header management
    - **Property 2: Token Header Management**
    - Verify: if token stored → Authorization header present with correct value; if no token → no Authorization header
    - **Validates: Requirements 2.5, 5.1, 5.7**

  - [x] 10.5 Write property test for HTTP error mapping
    - **Property 4: HTTP Error Mapping**
    - Generate random non-2xx status codes (excluding 401), verify Failure result with correct AppError; generate timeouts, verify NetworkError
    - **Validates: Requirements 5.5, 5.6**

- [x] 11. Flutter remote repositories — Auth and Profile
  - [x] 11.1 Implement RemoteAuthRepository
    - Create `lib/data/remote/remote_auth_repository.dart` implementing AuthRepository
    - Wire login, register, forgot-password, logout to ApiClient
    - Store token on successful login/register, clear on logout
    - _Requirements: 1.1, 1.4, 2.1, 2.4, 3.5, 4.2_

  - [x] 11.2 Implement RemoteProfileRepository
    - Create `lib/data/remote/remote_profile_repository.dart` implementing ProfileRepository
    - Wire create, get, update profile to ApiClient
    - _Requirements: 6.1, 6.3, 6.5, 6.7_

  - [x] 11.3 Wire auth and profile providers to use remote repositories
    - Create Riverpod provider overrides that swap mock implementations for remote ones
    - Update app initialization to use remote providers when backend is available
    - Ensure login success → store token + navigate to dashboard
    - Ensure register success → store token + navigate to profile setup
    - Handle password mismatch validation client-side before sending request
    - _Requirements: 1.4, 1.5, 1.6, 2.4, 2.6, 2.7, 4.2, 4.3, 4.4_

  - [x] 11.4 Write unit tests for RemoteAuthRepository
    - Test login/register/logout API path construction and response handling
    - Test token storage on success, error mapping on failure
    - _Requirements: 14.1_

- [x] 12. Flutter remote repositories — Exercises, Recommendations, Workouts, Progress
  - [x] 12.1 Implement RemoteExerciseRepository
    - Create `lib/data/remote/remote_exercise_repository.dart` implementing ExerciseRepository
    - Wire paginated listing with filters, single exercise detail
    - Implement infinite scroll: append next page when scrolling near bottom
    - _Requirements: 7.1, 7.2, 7.3, 7.7_

  - [x] 12.2 Implement RemoteWorkoutRepository
    - Create `lib/data/remote/remote_workout_repository.dart` implementing WorkoutRepository
    - Wire recommendation generation, current plan retrieval
    - Wire session start/pause/resume/skip/complete
    - Display local timer synchronized with session start timestamp
    - Handle completion failure: retain data locally, allow retry
    - _Requirements: 8.6, 9.1, 9.3, 9.4, 9.6, 9.7, 9.8, 9.9, 9.10_

  - [x] 12.3 Implement RemoteProgressRepository
    - Create `lib/data/remote/remote_progress_repository.dart` implementing ProgressRepository
    - Wire summary, history, weekly-stats endpoints
    - _Requirements: 10.1, 10.3, 10.4, 10.6_

  - [x] 12.4 Wire exercise, workout, and progress providers to remote repositories
    - Update Riverpod providers to use remote implementations
    - Ensure dashboard, workout, exercise library, and progress screens render real data
    - _Requirements: 7.7, 8.6, 9.8, 9.9, 10.6_

  - [x] 12.5 Write unit tests for remote repositories
    - Test correct API path construction, request body formatting, response deserialization
    - Test error handling for each repository method
    - _Requirements: 14.1_

- [x] 13. Checkpoint - Frontend integration complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Push notifications (FCM)
  - [x] 14.1 Implement DeviceTokenController in Laravel
    - POST /api/device-tokens — store/replace device token for authenticated user
    - _Requirements: 11.3_

  - [x] 14.2 Implement NotificationService in Laravel
    - Create `app/Services/NotificationService.php` for sending FCM messages
    - Send workout reminder 15 minutes before scheduled time (include workout name and time in payload)
    - Support system notifications (plan updates, milestones) to all user device tokens
    - Skip delivery if user has no registered device token
    - _Requirements: 11.4, 11.5, 11.9_

  - [x] 14.3 Implement FCM integration in Flutter
    - Create `lib/data/remote/remote_notification_repository.dart` implementing NotificationRepository
    - Request FCM token on app init, send to backend via POST /api/device-tokens
    - Retry registration up to 3 times with exponential backoff (1s, 2s, 4s)
    - Display in-app banner for foreground notifications (auto-dismiss 5s)
    - Handle notification tap: navigate to workout detail or dashboard if workout unavailable
    - _Requirements: 11.1, 11.2, 11.6, 11.7, 11.8_

  - [x] 14.4 Write feature tests for device token endpoint
    - Test registration, token replacement, unauthenticated request
    - _Requirements: 14.1, 14.2_

- [x] 15. Backend validation property tests
  - [x] 15.1 Write property test for registration validation field specificity
    - **Property 7: Registration Validation Field Specificity**
    - Generate random invalid registration payloads, verify 422 response has errors only for invalid fields, valid fields are absent from errors object
    - **Validates: Requirements 1.3**

  - [x] 15.2 Write property test for invalid credentials generic error
    - **Property 5: Invalid Credentials Generic Error**
    - Generate random invalid credentials (wrong email, wrong password, both wrong), verify identical 401 response with same generic message
    - **Validates: Requirements 2.2**

  - [x] 15.3 Write property test for forgot-password anti-enumeration
    - **Property 6: Forgot-Password Anti-Enumeration**
    - Generate random valid-format emails (some existing, some not), verify identical 200 response structure regardless of existence
    - **Validates: Requirements 3.2**

  - [x] 15.4 Write property test for exercise pagination and ordering
    - **Property 9: Exercise List Ordering and Pagination Metadata**
    - Generate random page sizes, verify alphabetical ordering, correct current_page, accurate total_count and total_pages
    - **Validates: Requirements 7.1**

  - [x] 15.5 Write property test for exercise filter correctness
    - **Property 10: Exercise Filter Correctness**
    - Generate random filter combinations, verify every returned exercise matches ALL provided filters
    - **Validates: Requirements 7.2**

  - [x] 15.6 Write property test for weekly stats accuracy
    - **Property 19: Weekly Stats Accuracy**
    - Generate random completed session dates within a week, verify returned counts per day match actual completed sessions
    - **Validates: Requirements 10.4**

  - [x] 15.7 Write property test for consistent API response envelope
    - **Property 20: Consistent API Response Envelope**
    - Hit various endpoints with valid/invalid data, verify all responses conform to the envelope structure with correct Content-Type header
    - **Validates: Requirements 12.1, 12.2, 12.3, 12.4**

- [x] 16. Final checkpoint - All tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The Laravel backend lives in a `backend/` directory at the repo root
- The Flutter frontend structure remains unchanged; only `lib/core/network/` and `lib/data/remote/` are added
- Mock repositories are preserved for development/testing flexibility
- Backend tests use PHPUnit with RefreshDatabase trait and SQLite in-memory
- Frontend property tests use the existing `glados` dev dependency

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3", "1.4"] },
    { "id": 3, "tasks": ["2.1", "2.2", "2.3", "2.4", "4.1"] },
    { "id": 4, "tasks": ["2.5", "3.1", "4.2"] },
    { "id": 5, "tasks": ["3.2", "3.3", "6.1"] },
    { "id": 6, "tasks": ["6.2"] },
    { "id": 7, "tasks": ["6.3", "7.1"] },
    { "id": 8, "tasks": ["6.4", "6.5", "6.6", "7.2", "8.1"] },
    { "id": 9, "tasks": ["7.3", "7.4", "7.5", "8.2", "8.3"] },
    { "id": 10, "tasks": ["10.1", "10.2"] },
    { "id": 11, "tasks": ["10.3", "10.4", "10.5", "11.1", "11.2"] },
    { "id": 12, "tasks": ["11.3", "11.4"] },
    { "id": 13, "tasks": ["12.1", "12.2", "12.3"] },
    { "id": 14, "tasks": ["12.4", "12.5"] },
    { "id": 15, "tasks": ["14.1", "14.2", "14.3"] },
    { "id": 16, "tasks": ["14.4", "15.1", "15.2", "15.3", "15.4", "15.5", "15.6", "15.7"] }
  ]
}
```
