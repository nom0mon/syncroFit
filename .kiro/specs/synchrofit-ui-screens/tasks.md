# Implementation Plan: SynchroFit UI Screens

## Overview

This implementation plan breaks the SynchroFit Flutter Android UI into incremental coding tasks. Each task builds on prior work, starting with core infrastructure (theme, models, routing), progressing through feature modules, and culminating with integration wiring. All screens use mock data via Riverpod providers with go_router navigation.

## Tasks

- [x] 1. Set up project structure, dependencies, and core models
  - [x] 1.1 Create project directory structure and shared data models
    - Create the feature-first folder structure under `lib/` as defined in the design (core/, features/, shared/, data/)
    - Implement all shared data model classes in `lib/shared/models/` (User, UserProfile, Exercise, Workout, WorkoutExercise, WorkoutSession, CompletedExercise, Post, Comment, Trainer, TimeSlot, Booking, NotificationItem, ProgressRecord)
    - Implement all enums (Gender, FitnessGoal, FitnessLevel, WorkoutPreference, DifficultyLevel, ActivityLevel, ConsultationType, NotificationType, DayOfWeek, TimerState)
    - Implement the `AppError` sealed class hierarchy (NotFoundError, ValidationError, AuthError, NetworkError)
    - _Requirements: 14.1_

  - [x] 1.2 Set up pubspec.yaml with all required dependencies
    - Add dependencies: `flutter_riverpod`, `go_router`, `fl_chart`, `shared_preferences`, `google_fonts`
    - Add dev dependencies: `flutter_test`, `mocktail`, `glados` (property-based testing)
    - Run `flutter pub get` to resolve packages
    - _Requirements: 14.2_

- [x] 2. Implement Theme System
  - [x] 2.1 Create the complete theme system in `lib/core/theme/`
    - Implement `app_colors.dart` with named color constants (primary, secondary, tertiary, surface variants, success-green, rest-blue)
    - Implement `app_spacing.dart` with spacing constants (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48)
    - Implement `app_text_styles.dart` with headline, title, body, label, caption text styles
    - Implement `component_themes.dart` with ElevatedButtonThemeData, InputDecorationTheme, CardTheme, AppBarTheme
    - Implement `app_theme.dart` with lightTheme and darkTheme using `ColorScheme.fromSeed()`
    - Create `theme.dart` barrel export file
    - _Requirements: 1.1, 1.2, 1.5, 1.6_

  - [ ]* 2.2 Write unit tests for theme system
    - Verify light and dark ThemeData objects are valid and non-null
    - Verify spacing constants match expected values
    - Verify component themes are applied correctly
    - _Requirements: 1.1, 1.2_

- [x] 3. Implement core utilities and shared widgets
  - [x] 3.1 Create form validators in `lib/core/utils/validators.dart`
    - Implement validateEmail, validatePassword, validateName, validateAge, validateHeight, validateWeight, validateRequired, validateMaxLength, validatePasswordMatch
    - All validators return null for valid input and an error string for invalid input
    - _Requirements: 3.6, 3.7, 3.11, 4.4, 5.6_

  - [x] 3.2 Create formatters in `lib/core/utils/formatters.dart`
    - Implement relative timestamp formatting (e.g., "2 hours ago", "3 days ago")
    - Implement duration formatting (seconds to mm:ss)
    - Implement date formatting utilities
    - _Requirements: 10.1, 12.1_

  - [x] 3.3 Create shared widgets in `lib/shared/widgets/`
    - Implement LoadingIndicator (centered spinner)
    - Implement ErrorDisplay (error message with retry button)
    - Implement EmptyState (centered icon + message)
    - Implement PageNotFoundScreen (404 with "Go to Dashboard" button)
    - _Requirements: 2.4, 15.1_

  - [ ]* 3.4 Write property tests for validators
    - **Property 2: Form Validation Rejects Invalid Input**
    - **Property 3: Password Confirmation Match**
    - **Property 4: Email Format Validation**
    - **Validates: Requirements 3.6, 3.7, 3.11, 4.4, 5.6**

- [x] 4. Implement Mock Data Layer
  - [x] 4.1 Create repository interfaces in `lib/data/repositories/`
    - Implement abstract classes: AuthRepository, ProfileRepository, ExerciseRepository, WorkoutRepository, CommunityRepository, ConsultationRepository, NotificationRepository, ProgressRepository
    - Each interface uses Future return types with Result<T, AppError> pattern
    - _Requirements: 14.2, 14.8_

  - [x] 4.2 Create mock seed data in `lib/data/mock/mock_data.dart`
    - Define at least 10 exercises across 3+ muscle groups
    - Define 3 workouts each with 4+ exercises
    - Define 5 posts each with 2+ comments
    - Define 3 trainers with available time slots
    - Define 5 notifications of varying types (2+ unread)
    - Define 5 progress records spanning 4+ weeks
    - Define sample user and user profile data
    - _Requirements: 14.4, 14.7_

  - [x] 4.3 Implement mock repositories in `lib/data/mock/`
    - Implement MockAuthRepository with simulated login/register/forgot-password (200-500ms delay)
    - Implement MockProfileRepository with CRUD on UserProfile
    - Implement MockExerciseRepository with getAll, getById, search, filterByMuscleGroup, filterByDifficulty
    - Implement MockWorkoutRepository with workout retrieval and session tracking
    - Implement MockCommunityRepository with posts, comments, likes CRUD
    - Implement MockConsultationRepository with trainers and bookings
    - Implement MockNotificationRepository with list, markRead operations
    - Implement MockProgressRepository with progress records
    - All operations use in-memory collections with artificial delays
    - _Requirements: 14.3, 14.5, 14.6_

  - [ ]* 4.4 Write property tests for mock repositories
    - **Property 10: CRUD Collection Consistency**
    - **Property 14: Mock Repository Response Completeness**
    - **Validates: Requirements 14.4, 14.5, 14.6**

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement Router and Navigation
  - [x] 6.1 Implement the go_router configuration in `lib/core/router/`
    - Create `route_names.dart` with named route constants for all screens
    - Create `guards.dart` with auth redirect logic
    - Create `app_router.dart` with full GoRouter configuration including StatefulShellRoute.indexedStack for 5 tabs
    - Define all routes with path parameters for detail screens (exercise/:id, post/:id, trainer/:id, workout/:id, session/:id)
    - Configure errorBuilder to render PageNotFoundScreen
    - Wire auth guard redirect logic checking authStateProvider
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9_

  - [ ]* 6.2 Write property tests for router
    - **Property 11: Undefined Route Handling**
    - **Property 12: Auth Guard Redirect**
    - **Validates: Requirements 2.4, 2.8, 2.9**

- [x] 7. Implement Auth Module
  - [x] 7.1 Create auth provider in `lib/features/auth/providers/auth_provider.dart`
    - Implement authStateProvider (StateNotifier) managing authentication state
    - Implement login, register, forgotPassword methods calling MockAuthRepository
    - Handle error states and surface them to UI
    - _Requirements: 3.4, 3.5, 3.8, 3.9, 3.10_

  - [x] 7.2 Implement Auth screens in `lib/features/auth/screens/`
    - Implement LoginScreen with email/password fields, submit button, links to register and forgot-password
    - Implement RegisterScreen with name, email, password, confirm-password fields and submit button
    - Implement ForgotPasswordScreen with email field and submit button
    - All forms use validators.dart for inline validation
    - Display snackbar errors from mock repository failures
    - _Requirements: 3.1, 3.2, 3.3, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11_

  - [ ]* 7.3 Write widget tests for Auth screens
    - Test form rendering and validation error display
    - Test navigation links between auth screens
    - Test snackbar display on mock errors
    - _Requirements: 3.6, 3.7, 3.8, 3.9_

- [x] 8. Implement Profile and Assessment Modules
  - [x] 8.1 Create profile provider in `lib/features/profile/providers/profile_provider.dart`
    - Implement profileProvider (AsyncNotifier) managing user profile state
    - Implement save and update methods calling MockProfileRepository
    - _Requirements: 4.3, 4.7_

  - [x] 8.2 Implement Profile screens in `lib/features/profile/screens/`
    - Implement ProfileSetupScreen with all fields: name, age, height, weight, gender dropdown, fitness goal dropdown, fitness level dropdown, workout preference dropdown, workout availability multi-select
    - Implement ProfileEditScreen pre-populated with existing mock data, reusing the same form layout
    - All fields use validators.dart for inline validation
    - _Requirements: 4.1, 4.2, 4.4, 4.5, 4.6, 4.7, 4.8, 13.8_

  - [x] 8.3 Create assessment provider in `lib/features/assessment/providers/assessment_provider.dart`
    - Implement assessmentProvider managing multi-step form state
    - Implement BMI calculation (weight / (height/100)²) rounded to 1 decimal
    - Persist step data so back navigation retains entered values
    - _Requirements: 5.3, 5.4, 5.7_

  - [x] 8.4 Implement Assessment screens in `lib/features/assessment/screens/`
    - Implement BmiStepScreen (step 1): height and weight inputs with real-time BMI display
    - Implement PhysicalInfoStepScreen (step 2): age, gender, activity level
    - Implement GoalsStepScreen (step 3): fitness goal, training experience
    - Display progress indicator showing current step (e.g., "Step 2 of 3")
    - Each step validates before advancing; back navigation retains data
    - Final step saves to MockRepository and navigates to Dashboard
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [ ]* 8.5 Write property test for BMI calculation
    - **Property 1: BMI Calculation Accuracy**
    - **Validates: Requirements 5.7**

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement Dashboard and Workout Modules
  - [x] 10.1 Create dashboard provider in `lib/features/dashboard/providers/dashboard_provider.dart`
    - Implement dashboardProvider fetching today's workout, weekly progress, goal percentage, streak from MockRepository
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 10.2 Implement Dashboard screen in `lib/features/dashboard/screens/dashboard_screen.dart`
    - Display "Today's Workout" card (name, duration, exercise count) — tappable to navigate to workout detail
    - Display weekly progress section (completed/planned days) — tappable to navigate to progress
    - Display goal progress indicator with percentage and progress bar
    - Display workout streak counter
    - Show empty state when no workout scheduled
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [x] 10.3 Create workout and timer providers in `lib/features/workout/providers/`
    - Implement workoutProvider managing current workout session state
    - Implement TimerController (Notifier) with start, pause, resume, reset, skip methods using Timer.periodic
    - Track exercise progression and completed exercises for summary
    - _Requirements: 7.2, 7.3, 7.4, 7.10_

  - [x] 10.4 Implement Workout screens in `lib/features/workout/screens/`
    - Implement WorkoutDetailScreen listing all exercises with name, sets, reps/duration, thumbnail, and "Start Workout" button
    - Implement WorkoutActiveScreen with current exercise display, countdown timer, start/pause/resume/skip/complete controls
    - Implement RestTimerScreen with countdown (10-120s, default 30s) and skip button
    - Implement WorkoutSummaryScreen showing total duration, exercises completed, congratulatory message
    - Wire navigation flow: detail → active → rest → next exercise → summary
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9_

  - [ ]* 10.5 Write property test for workout summary accuracy
    - **Property 13: Workout Session Summary Accuracy**
    - **Validates: Requirements 7.9**

  - [ ]* 10.6 Write unit tests for TimerController
    - Test state transitions: idle → running → paused → running → completed
    - Test skip behavior and reset behavior
    - _Requirements: 7.3, 7.4, 7.10_

- [x] 11. Implement Exercise Library Module
  - [x] 11.1 Create exercise provider in `lib/features/exercise_library/providers/exercise_provider.dart`
    - Implement exerciseProvider with list, search, and filter methods calling MockExerciseRepository
    - Support filtering by multiple muscle groups and difficulty level simultaneously
    - Support case-insensitive substring search updating results on input change
    - _Requirements: 8.2, 8.3_

  - [x] 11.2 Implement Exercise Library screens in `lib/features/exercise_library/screens/`
    - Implement ExerciseListScreen with exercise list items (name, muscle group, difficulty, image placeholder), filter controls, and search input
    - Implement ExerciseDetailScreen with full exercise info (name, muscle group, numbered instructions, equipment, difficulty, image placeholder)
    - Display empty state when no exercises match filters/search
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [ ]* 11.3 Write property test for exercise filtering
    - **Property 5: Exercise Filter Correctness**
    - **Validates: Requirements 8.2, 8.3**

- [x] 12. Implement Progress Module
  - [x] 12.1 Create progress provider in `lib/features/progress/providers/progress_provider.dart`
    - Implement progressProvider fetching summary stats, weight history, BMI history, weekly stats, and completed sessions from MockRepository
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [x] 12.2 Implement Progress screens in `lib/features/progress/screens/`
    - Implement ProgressSummaryScreen with total workouts, current/longest streak, current weight
    - Add weight history line chart (fl_chart) with 5+ data points, labeled axes
    - Add BMI history line chart with 5+ data points, labeled axes
    - Add weekly statistics bar chart for last 4 weeks
    - Display list of 5+ recent completed workouts (name, date, duration, exercise count)
    - Implement SessionDetailScreen showing exercises performed (name, sets, reps/duration)
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

- [x] 13. Implement Community Module
  - [x] 13.1 Create community provider in `lib/features/community/providers/community_provider.dart`
    - Implement communityProvider managing posts, likes, and comments
    - Implement like toggle (increment/decrement count, toggle liked state)
    - Implement comment submission (validate non-whitespace, prepend to list, clear input)
    - Implement content truncation logic (150 chars + ellipsis)
    - _Requirements: 10.4, 10.5, 10.6_

  - [x] 13.2 Implement Community screens in `lib/features/community/screens/`
    - Implement FeedScreen with scrollable post list (author, truncated content, like count, comment count, relative timestamp)
    - Implement PostDetailScreen with full content, author, timestamp, like button with toggle, comments list, comment input (max 500 chars)
    - Like button shows filled/outlined icon based on state
    - Comment validation prevents empty/whitespace-only submission
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_

  - [ ]* 13.3 Write property tests for community features
    - **Property 6: Content Truncation**
    - **Property 7: Like Toggle Consistency**
    - **Property 8: Comment Submission Validity**
    - **Validates: Requirements 10.1, 10.4, 10.5, 10.6**

- [x] 14. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 15. Implement Consultation Module
  - [x] 15.1 Create consultation provider in `lib/features/consultation/providers/consultation_provider.dart`
    - Implement consultationProvider fetching trainers, trainer details, and handling booking submissions
    - _Requirements: 11.5_

  - [x] 15.2 Implement Consultation screens in `lib/features/consultation/screens/`
    - Implement TrainerListScreen displaying trainers (name, specialization, rating, avatar placeholder)
    - Implement TrainerProfileScreen with full trainer info (name, bio, specialization, rating, experience, available slots, avatar) and "Book Consultation" button
    - Implement BookingFormScreen with date picker (no past dates), time slot selector, consultation type (in-person/video call), notes field (max 500 chars)
    - Validate required fields on booking submission; display confirmation on success
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7_

- [x] 16. Implement Notifications Module
  - [x] 16.1 Create notifications provider in `lib/features/notifications/providers/notifications_provider.dart`
    - Implement notificationsProvider fetching notifications ordered by timestamp descending
    - Implement markAsRead method updating notification state
    - _Requirements: 12.1, 12.2_

  - [x] 16.2 Implement Notifications screen in `lib/features/notifications/screens/notifications_screen.dart`
    - Display scrollable list ordered newest-first with title (truncated 80 chars), description (truncated 200 chars), relative timestamp, read/unread indicator
    - Visually distinguish read/unread via background color or text weight
    - Tap unread → mark as read; tap already-read → no change
    - Display empty state when no notifications
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

  - [ ]* 16.3 Write property test for notification ordering
    - **Property 9: Notification Ordering**
    - **Validates: Requirements 12.1**

- [x] 17. Implement Settings Module
  - [x] 17.1 Create settings provider in `lib/features/settings/providers/settings_provider.dart`
    - Implement settingsProvider managing notification preferences (workout reminders, community updates, achievement alerts, consultation reminders)
    - Implement themeProvider (StateProvider<ThemeMode>) with SharedPreferences persistence
    - Implement change password logic calling MockRepository
    - _Requirements: 13.2, 13.6, 13.7_

  - [x] 17.2 Implement Settings screens in `lib/features/settings/screens/`
    - Implement SettingsMainScreen with navigation to Edit Profile, Notification Settings, Change Password, and inline theme toggle switch
    - Implement NotificationSettingsScreen with toggles (all default enabled, persisted across visits)
    - Implement ChangePasswordScreen with current password, new password, confirm password fields and validation
    - Wire Edit Profile navigation to ProfileEditScreen (reuse from Profile module)
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8_

- [x] 18. Wire app entry point and integrate all modules
  - [x] 18.1 Implement `lib/app.dart` and `lib/main.dart`
    - Create `app.dart` with MaterialApp.router wrapped in ProviderScope
    - Wire GoRouter via appRouterProvider
    - Apply theme system with themeProvider for dynamic light/dark switching
    - Create `main.dart` with runApp entry point
    - Ensure bottom navigation bar renders on primary tab screens with 5 tabs (Dashboard, Exercise Library, Progress, Community, Settings)
    - Verify all routes are connected and navigable end-to-end
    - _Requirements: 1.3, 1.4, 2.6, 2.7, 15.1, 15.2, 15.3, 15.4, 15.5_

  - [ ]* 18.2 Write integration tests for critical flows
    - Test auth flow: register → profile setup → assessment → dashboard
    - Test workout flow: dashboard → detail → active → rest → summary
    - Test tab navigation preserves per-tab state
    - Test theme toggle persistence
    - _Requirements: 2.3, 2.6, 3.4, 5.3, 7.1_

- [x] 19. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- All screens use mock data — no backend integration required
- The fl_chart library is used for progress charts (weight history, BMI history, weekly stats)
- SharedPreferences is used for theme mode persistence only
- Timer logic is purely UI-layer using Dart's Timer.periodic

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "3.1", "3.2", "3.3"] },
    { "id": 2, "tasks": ["2.2", "3.4", "4.1"] },
    { "id": 3, "tasks": ["4.2", "4.3"] },
    { "id": 4, "tasks": ["4.4", "6.1"] },
    { "id": 5, "tasks": ["6.2", "7.1", "8.1", "8.3"] },
    { "id": 6, "tasks": ["7.2", "8.2", "8.4"] },
    { "id": 7, "tasks": ["7.3", "8.5", "10.1", "10.3"] },
    { "id": 8, "tasks": ["10.2", "10.4", "11.1", "12.1", "13.1"] },
    { "id": 9, "tasks": ["10.5", "10.6", "11.2", "12.2", "13.2"] },
    { "id": 10, "tasks": ["11.3", "13.3", "15.1", "16.1", "17.1"] },
    { "id": 11, "tasks": ["15.2", "16.2", "16.3", "17.2"] },
    { "id": 12, "tasks": ["18.1"] },
    { "id": 13, "tasks": ["18.2"] }
  ]
}
```
