# Requirements Document

## Introduction

This document specifies the requirements for building the core backend (Laravel 12 + MySQL 8 + Sanctum) for SynchroFit and wiring it to the existing Flutter frontend. The project foundation and all frontend screens (using mock data) already exist. The approach is vertical-slice: implement each Laravel API feature, then immediately wire the corresponding Flutter screen(s) to consume real data instead of mocks.

Out of scope: community/social features, consultation/trainer features, real-time chat, comprehensive QA pass, release build.

## Glossary

- **Backend**: The Laravel 12 application serving a RESTful JSON API over HTTPS, backed by MySQL 8
- **Frontend**: The existing Flutter (Dart) Android application using Riverpod for state management and GoRouter for navigation
- **Sanctum**: Laravel Sanctum token-based authentication middleware used to protect API endpoints
- **API_Client**: A centralized HTTP client class in the Flutter app responsible for attaching auth tokens, parsing JSON responses, and surfacing errors
- **Recommendation_Engine**: A testable Laravel service class (app/Services/RecommendationEngine.php) that generates personalized weekly workout plans
- **Workout_Session**: A record of a user performing a workout, including start/pause/resume/skip/complete states and per-exercise completion data
- **FCM**: Firebase Cloud Messaging, used to deliver push notifications to Android devices
- **Device_Token**: A unique string identifying a specific device for push notification delivery via FCM
- **Profile**: The user's fitness assessment data including age, height, weight, gender, goal, fitness level, workout preference, and availability
- **Exercise_Library**: The collection of all exercises stored in the database, filterable by muscle group, equipment, and difficulty
- **Progress_Record**: A timestamped snapshot of a user's weight, BMI, and workout completion count
- **Weekly_Plan**: A generated set of daily workouts (exercises, sets, reps, rest periods) for seven days, produced by the Recommendation_Engine

## Requirements

### Requirement 1: User Registration

**User Story:** As a new user, I want to register with my name, email, and password, so that I can create an account and access the app.

#### Acceptance Criteria

1. WHEN a registration request is received with a name between 1 and 50 characters, a valid-format email of no more than 254 characters, and a password between 8 and 128 characters, THE Backend SHALL create a new user record, issue a Sanctum authentication token, and return a JSON response with shape {"success": true, "data": {"user": {...}, "token": "..."}, "message": "..."}
2. IF the registration request contains an email that already exists in the database, THEN THE Backend SHALL return a 422 response with a validation error message indicating the email is already taken
3. IF the registration request is missing required fields or contains invalid data (invalid email format, name empty or exceeding 50 characters, password under 8 characters or exceeding 128 characters), THEN THE Backend SHALL return a 422 response with field-specific validation error messages identifying each invalid field
4. WHEN a successful registration response is received, THE Frontend SHALL store the authentication token in platform-secured storage (Flutter secure storage) and navigate the user to the profile setup screen
5. IF the registration request fails due to a network error or the Backend returning a non-2xx response other than 422, THEN THE Frontend SHALL display an error message to the user and remain on the registration screen with all previously entered field values preserved
6. WHEN the user submits the registration form, THE Frontend SHALL validate that the password and confirm-password fields match before sending the request to the Backend, and IF they do not match, THEN THE Frontend SHALL display a field-specific error message and not send the request

### Requirement 2: User Login

**User Story:** As a returning user, I want to log in with my email and password, so that I can access my account and data.

#### Acceptance Criteria

1. WHEN a login request is received with a valid email (matching the pattern `^[^@]+@[^@]+\.[^@]+$`) and a password of at least 8 characters that match an existing account, THE Backend SHALL authenticate the user, issue a Sanctum token, and return the response in the standard JSON shape `{"success": true, "data": {"user": {...}, "token": "..."}, "message": "...", "errors": null}`
2. IF the login request contains credentials that do not match any existing account, THEN THE Backend SHALL return a 401 response with `{"success": false, "data": null, "message": "Invalid email or password", "errors": null}` that does not reveal whether the email or password was incorrect
3. IF the login request is missing the email or password field, or the email does not match the required format, or the password is fewer than 8 characters, THEN THE Backend SHALL return a 422 validation error response without attempting authentication
4. WHEN a successful login response is received, THE Frontend SHALL store the authentication token in platform-secure storage (Flutter secure storage or equivalent), and navigate the user to the dashboard screen within 2 seconds of receiving the response
5. WHILE the user holds a non-expired authentication token, THE Frontend SHALL attach it to all subsequent API requests via the `Authorization: Bearer <token>` header
6. IF an API request returns a 401 Unauthorized response indicating the token is invalid or expired, THEN THE Frontend SHALL clear the stored token and navigate the user to the login screen
7. WHILE a login request is in progress, THE Frontend SHALL disable the sign-in button and display a loading indicator until the response is received or a timeout of 30 seconds elapses

### Requirement 3: Forgot Password

**User Story:** As a user who forgot their password, I want to request a password reset email, so that I can regain access to my account.

#### Acceptance Criteria

1. WHEN a forgot-password request is received with a valid email that exists in the database, THE Backend SHALL generate a password reset link with a token that expires after 60 minutes, send it to the specified email address, and return a 200 response with `{"success": true, "message": "..."}` confirming the request was accepted
2. IF the forgot-password request contains an email not in the database, THEN THE Backend SHALL return a 200 response with an identical response structure and message to criterion 1 to prevent email enumeration attacks
3. IF the forgot-password request is missing the email field or contains an email not matching a valid email format, THEN THE Backend SHALL return a 422 response with a field-specific validation error in the `errors` object identifying the email field
4. IF the same email address submits more than 5 forgot-password requests within a 15-minute window, THEN THE Backend SHALL return a 429 response with a message indicating the user should wait before retrying
5. WHEN the Frontend receives a successful forgot-password response, THE Frontend SHALL display a confirmation message indicating that reset instructions have been sent and remain on the forgot-password screen

### Requirement 4: User Logout

**User Story:** As a logged-in user, I want to log out, so that my session is terminated and my token is invalidated.

#### Acceptance Criteria

1. WHEN a logout request is received with a valid Sanctum token via POST /api/logout, THE Backend SHALL revoke the token and return a 200 response with `{"success": true, "data": null, "message": "..."}` confirming logout
2. WHEN the user triggers logout in the Frontend, THE Frontend SHALL send a POST /api/logout request to the Backend, then clear the stored authentication token from flutter_secure_storage, and navigate to the login screen
3. WHEN the Frontend receives a 401 Unauthorized response from any API call, THE Frontend SHALL clear the stored token from flutter_secure_storage and redirect the user to the login screen
4. IF the POST /api/logout request fails due to a network error or non-200 response, THEN THE Frontend SHALL still clear the stored authentication token from flutter_secure_storage and navigate to the login screen
5. IF a logout request is received with an invalid, expired, or missing token, THEN THE Backend SHALL return a 401 response with `{"success": false, "data": null, "message": "...", "errors": ...}` and no token revocation shall occur

### Requirement 5: Centralized HTTP Client

**User Story:** As a developer, I want a single HTTP client class in the Flutter app, so that token management, error handling, and loading states are consistent across all screens.

#### Acceptance Criteria

1. IF a Sanctum token is stored, THEN THE API_Client SHALL attach it to every outgoing request as a Bearer token in the Authorization header
2. THE API_Client SHALL parse all API responses (JSON format: {"success", "data", "message", "errors"}) into the project's existing Result type, mapping success responses to Success with typed data and error responses to Failure with an AppError containing the server-provided message and HTTP status code
3. WHEN the API_Client receives a 401 response, THE API_Client SHALL clear the stored token and navigate to the login screen
4. THE API_Client SHALL expose a per-request loading state as a Riverpod provider that emits true when a request starts and false when it completes or fails, allowing each screen to independently observe its own loading indicator
5. IF a network timeout occurs (exceeding 30 seconds) or no network connectivity is detected, THEN THE API_Client SHALL return a Failure result with a NetworkError indicating the nature of the failure (timeout vs. no connectivity)
6. IF the API_Client receives a non-401 HTTP error response (e.g., 403, 404, 422, 500), THEN THE API_Client SHALL return a Failure result with an AppError containing the HTTP status code and the error message from the response body
7. IF no Sanctum token is stored when a request is initiated, THEN THE API_Client SHALL send the request without an Authorization header

### Requirement 6: Profile and Fitness Assessment CRUD

**User Story:** As a user, I want to create and manage my fitness profile (age, height, weight, gender, goal, fitness level, workout preference, availability), so that the app can personalize my experience.

#### Acceptance Criteria

1. WHEN a profile creation request is received with all required fields (age, height_cm, weight_kg, gender, goal, fitness_level, workout_preference, availability_days), THE Backend SHALL create the profile record linked to the authenticated user and return the profile object with all stored fields and the computed BMI value.
2. IF a profile creation request is received for a user who already has a profile, THEN THE Backend SHALL return a 409 response with an error message indicating a profile already exists.
3. WHEN a profile retrieval request is received for a user who has a profile, THE Backend SHALL return the authenticated user's profile data including a computed BMI value (weight in kg divided by height in meters squared, rounded to 2 decimal places).
4. IF a profile retrieval request is received for a user who has no profile, THEN THE Backend SHALL return a 404 response with an error message indicating no profile exists.
5. WHEN a profile update request is received with valid fields, THE Backend SHALL update only the provided fields, recalculate the BMI if height_cm or weight_kg changed, and return the updated profile object.
6. IF a profile request is missing required fields or contains invalid values (age outside 13–120, weight_kg outside 20–500, height_cm outside 50–300, gender not in [male, female, other], goal not in [lose_weight, build_muscle, stay_fit, increase_stamina], fitness_level not in [beginner, intermediate, advanced], workout_preference not in [home, gym, outdoor], or availability_days not a non-empty array of values from [monday, tuesday, wednesday, thursday, friday, saturday, sunday] with no duplicates and at most 7 entries), THEN THE Backend SHALL return a 422 response with field-specific validation errors identifying each invalid field.
7. WHEN the Frontend receives profile data, THE Frontend SHALL populate the profile and assessment screens with the returned field values and display the BMI value.

### Requirement 7: Exercise Library Listing with Pagination

**User Story:** As a user, I want to browse the exercise library with pagination, so that I can discover exercises without loading the entire collection at once.

#### Acceptance Criteria

1. WHEN an exercise list request is received, THE Backend SHALL return a paginated list of exercises sorted by name in ascending alphabetical order, with a default page size of 20 and pagination metadata including current page number, total pages, and total exercise count
2. WHEN filter parameters are provided (muscle_group, equipment, difficulty), THE Backend SHALL return only exercises matching all provided filters, applying the same pagination and metadata structure; IF any filter value does not match a valid enum option, THEN THE Backend SHALL ignore that filter parameter and return results as if it were not provided
3. WHEN a single exercise detail request is received with a valid exercise ID, THE Backend SHALL return the full exercise record including name, description, instructions, muscle_group, equipment, difficulty, default_sets, default_reps, default_duration_seconds, and image_url
4. IF the requested exercise ID does not exist, THEN THE Backend SHALL return an error response indicating the exercise was not found
5. IF the requested page number exceeds available pages, THEN THE Backend SHALL return an empty data array with pagination metadata reflecting the total count and total pages accurately
6. IF the page parameter is less than 1 or is not a valid integer, THEN THE Backend SHALL treat the request as page 1
7. WHEN the Frontend receives paginated exercise data, THE Frontend SHALL append the next page of results below previously loaded items when the user scrolls within 200px of the list bottom, without removing previously displayed exercises

### Requirement 8: Recommendation Engine

**User Story:** As a user, I want the app to generate a personalized weekly workout plan based on my profile, goals, fitness level, and equipment, so that I get effective training guidance.

#### Acceptance Criteria

1. WHEN a recommendation generation request is received for an authenticated user, THE Recommendation_Engine SHALL produce a Weekly_Plan containing one workout per workout availability day, where each workout includes 4 to 8 exercises, each exercise specifying sets (2–5), reps (5–20), and rest periods (30–120 seconds), selected based on the user's fitness goal, fitness level, and available equipment
2. THE Recommendation_Engine SHALL complete the generation of a Weekly_Plan within 5 seconds for any valid user profile
3. WHEN a user has completed workout history of at least 2 weeks, THE Recommendation_Engine SHALL apply rule-based adaptation: increase volume by 5–10% if the user completed 80% or more of scheduled workouts in the previous 2 weeks, and decrease volume by 5–10% if the user skipped 50% or more of scheduled workouts in the previous 2 weeks
4. IF the user's profile is incomplete (missing fitness goal or fitness level), THEN THE Recommendation_Engine SHALL return a 422 response indicating which profile fields are required before generation
5. IF a user has no workout history, THEN THE Recommendation_Engine SHALL generate a baseline Weekly_Plan using default volume settings for the user's fitness level without adaptation adjustments
6. WHEN the Frontend receives a generated Weekly_Plan, THE Frontend SHALL display the plan on the dashboard and workout screens showing each day's exercises with their sets, reps, and rest periods, replacing mock workout data
7. THE Recommendation_Engine SHALL produce different exercise selections and volume ranges for each fitness goal (lose_weight, build_muscle, stay_fit, increase_stamina) and each fitness level (beginner, intermediate, advanced)

### Requirement 9: Workout Tracking

**User Story:** As a user, I want to track my workouts in real-time (start, pause, resume, skip exercises, complete), so that my effort is recorded and progress is accurate.

#### Acceptance Criteria

1. WHEN a workout start request is received, THE Backend SHALL create a Workout_Session record with a "started" status and timestamp, associate the exercises from the specified workout plan with the session (each defaulting to "pending" status), and return the session ID
2. IF a workout start request is received and the user already has a session in "started" or "paused" status, THEN THE Backend SHALL reject the request with an error indicating that an active session already exists
3. WHEN a pause request is received for an active session, THE Backend SHALL record a pause timestamp and update the session status to "paused"
4. WHEN a resume request is received for a paused session, THE Backend SHALL record the resume timestamp and update the session status to "active"
5. IF a state-transition request is received for a session that is not in the required status (e.g., pause for a non-active session, resume for a non-paused session, or any action on a "completed" session), THEN THE Backend SHALL reject the request with an error indicating the current session status and the invalid transition attempted
6. WHEN a skip-exercise request is received for an active session, THE Backend SHALL mark the specified exercise as "skipped" in the session record, provided the exercise status is "pending"
7. WHEN a complete request is received for an active or paused session, THE Backend SHALL calculate total duration (excluding paused time), record each exercise's final status and actual sets/reps performed, update the session status to "completed", and return the completed session summary including total duration, exercise count, and per-exercise completion data
8. WHILE a workout session is active in the Frontend, THE Frontend SHALL display elapsed time using a local timer synchronized with the session start timestamp from the Backend, updating at 1-second intervals
9. WHEN the Frontend submits workout completion, THE Frontend SHALL persist the session data via the complete API endpoint and update the local workout history upon a successful response
10. IF the Frontend workout completion API call fails, THEN THE Frontend SHALL retain the session data locally and display an error message indicating the save failed, allowing the user to retry submission

### Requirement 10: Progress Tracking and Dashboard

**User Story:** As a user, I want to view my workout history, streaks, weight/BMI trends, and weekly statistics, so that I can monitor my fitness journey.

#### Acceptance Criteria

1. WHEN a progress summary request is received, THE Backend SHALL return the total completed workouts, current streak (consecutive calendar days ending on today with at least one completed workout session, resetting to 0 if today or yesterday has no completed session), longest streak, and the weight_kg value from the most recent Progress_Record for the authenticated user
2. IF a progress summary request is received and the authenticated user has no Progress_Record entries, THEN THE Backend SHALL return 0 for total completed workouts, 0 for current streak, 0 for longest streak, and null for current weight
3. WHEN a weight/BMI history request is received, THE Backend SHALL return all Progress_Record entries ordered by date ascending for the authenticated user
4. WHEN a weekly stats request is received, THE Backend SHALL return the number of workouts completed per day for each day of the current week (Monday through Sunday), including 0 for days with no completed workouts
5. WHEN a new workout session is completed, THE Backend SHALL create or update the Progress_Record for that date by incrementing the workouts_completed count by 1 and preserving the existing weight_kg and bmi values if already set
6. WHEN the Frontend receives progress and dashboard data, THE Frontend SHALL render the calendar grid, weekly load chart, and completed sessions widgets with real data from the API

### Requirement 11: Push Notifications for Workout Reminders

**User Story:** As a user, I want to receive push notifications reminding me of scheduled workouts, so that I stay consistent with my fitness plan.

#### Acceptance Criteria

1. WHEN the Frontend initializes, THE Frontend SHALL request the FCM Device_Token and send it to the Backend via POST /api/device-tokens for registration
2. IF the device token registration request fails due to network error or server rejection, THEN THE Frontend SHALL retry the registration up to 3 times with exponential backoff and silently discard the request if all retries fail
3. WHEN a device token registration request is received, THE Backend SHALL store the Device_Token associated with the authenticated user, replacing any previous token for that device
4. WHEN a scheduled workout time is 15 minutes away, THE Backend SHALL send a push notification to the user's registered Device_Token via FCM containing the workout name and scheduled time
5. IF the Backend detects that a user has no registered Device_Token at notification dispatch time, THEN THE Backend SHALL skip notification delivery for that user without error
6. WHILE the app is in the foreground, WHEN a push notification is received, THE Frontend SHALL display an in-app notification banner that auto-dismisses after 5 seconds or upon user tap
7. WHEN a push notification is tapped (foreground or background), THE Frontend SHALL navigate to the workout detail screen for the workout identified in the notification payload
8. IF the workout referenced in a tapped notification no longer exists, THEN THE Frontend SHALL navigate to the dashboard screen and display a message indicating the workout is no longer available
9. THE Backend SHALL support sending system notification messages (e.g., plan updates, milestone achievements) to all registered Device_Tokens for a given user

### Requirement 12: Consistent API Response Format

**User Story:** As a developer, I want all API endpoints to return a consistent JSON response shape, so that the Frontend can parse responses uniformly.

#### Acceptance Criteria

1. THE Backend SHALL return all successful responses with the JSON structure: `{"success": true, "data": <payload>, "message": <string or null>}`, where `data` contains the response payload and `message` is `null` when no descriptive text is applicable
2. THE Backend SHALL return all error responses with the JSON structure: `{"success": false, "message": <string describing the error>, "errors": <object or null>}`, where `errors` is an object mapping field names to an array of validation message strings when the error is a validation failure (HTTP 422), and `null` for all other error types
3. THE Backend SHALL use standard HTTP status codes: 200 for success, 201 for resource creation, 401 for unauthenticated, 403 for unauthorized, 404 for not found, 422 for validation errors, 500 for server errors
4. THE Backend SHALL set the `Content-Type` response header to `application/json` for all API responses
5. IF an unhandled exception occurs, THEN THE Backend SHALL return a response with HTTP status 500 conforming to the error JSON structure defined in criterion 2, with `message` set to a generic error indication and `errors` set to `null`, ensuring no raw framework error pages or stack traces are exposed to the client

### Requirement 13: Database Migrations

**User Story:** As a developer, I want all database tables defined as Laravel migrations, so that the schema is version-controlled and reproducible.

#### Acceptance Criteria

1. THE Backend SHALL include Laravel migration files for all tables: users, profiles, exercises, workouts, workout_exercises, workout_sessions, session_exercises, progress_records, device_tokens, and recommendations, ordered so that parent tables are created before child tables that reference them via foreign keys
2. WHEN migrations are executed, THE Backend SHALL create all tables with foreign key constraints linking each child table to its parent table and indexes on all foreign key columns and columns used in WHERE or ORDER BY clauses for list queries (e.g., exercises.muscle_group, exercises.difficulty, workout_sessions.completed_at, progress_records.recorded_at)
3. THE Backend SHALL include seed data for the exercise library containing a minimum of 30 exercises, with at least 2 exercises per muscle group (chest, back, shoulders, biceps, triceps, legs, core, full_body), at least 2 exercises per equipment type (bodyweight, dumbbell, barbell, kettlebell, resistance_band, machine, pull_up_bar), and at least 5 exercises per difficulty level (beginner, intermediate, advanced)
4. IF the users table already exists from the default Laravel installation, THEN THE Backend SHALL skip creation of the users table and only add application-specific columns via a separate migration that alters the existing table

### Requirement 14: API Test Coverage

**User Story:** As a developer, I want automated tests for every API endpoint, so that regressions are caught early.

#### Acceptance Criteria

1. THE Backend SHALL include feature tests for every API endpoint (register, login, forgot-password, logout, profile CRUD, exercises list/detail, recommendation generation, workout session start/pause/resume/skip/complete, progress summary/history/weekly-stats, and device token registration) covering the happy path by asserting the correct HTTP status code and that the response body matches the consistent JSON structure defined in Requirement 12
2. THE Backend SHALL include feature tests for every API endpoint covering at least one validation failure scenario (invalid input returning 422 with field-specific errors) and at least one authentication failure scenario (missing or invalid token returning 401) for each protected endpoint
3. WHEN the test suite is executed, THE Backend SHALL produce a passing result for all tests without requiring external services, using SQLite in-memory or a dedicated test database, with each test class using the RefreshDatabase trait to ensure test isolation
4. THE Recommendation_Engine SHALL have dedicated unit tests covering generation for beginner, intermediate, and advanced fitness levels, all supported fitness goals, and the missing-profile-data edge case returning a validation error
5. WHEN any single feature test is executed, THE Backend SHALL complete the test within 5 seconds, and the full test suite SHALL complete within 60 seconds
