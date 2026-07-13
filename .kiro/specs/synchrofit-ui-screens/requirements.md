# Requirements Document

## Introduction

SynchroFit UI Screens implements the complete set of Flutter UI screens for the SynchroFit Android fitness application. These screens cover authentication, profile management, fitness assessment, dashboard, workouts, exercise library, progress tracking, community, consultation, notifications, and settings. All screens use mock/stub data and are navigable end-to-end via a centralized router. Real API integration is deferred to Phase 4.

## Glossary

- **Flutter_App**: The Android-only Flutter mobile application (`synchrofit_app`).
- **Router**: The centralized navigation system (go_router) managing all route definitions and transitions within the Flutter_App.
- **Theme_System**: The single source of truth for colors, typography, spacing, and component styles defined in `lib/core/theme`.
- **Mock_Repository**: A local data provider that returns hardcoded or generated placeholder data, allowing screens to compile and function without a live backend.
- **Screen**: A full-page Flutter widget representing a distinct view in the application.
- **Auth_Module**: The set of screens handling user registration, login, and password recovery.
- **Profile_Module**: The set of screens for creating and editing user profile information.
- **Assessment_Module**: The guided flow that collects fitness assessment data (BMI inputs, physical info, experience, goals).
- **Dashboard_Screen**: The main landing screen displaying today's workout, weekly progress, goal progress, and workout streak.
- **Workout_Module**: The set of screens for viewing exercises in a workout session and controlling playback (start, pause, resume, skip, complete) with timer logic.
- **Exercise_Library**: The browsable collection of exercises with list and detail views.
- **Progress_Module**: The set of screens displaying completed workouts, streaks, weight history, BMI changes, and weekly statistics.
- **Community_Module**: The set of screens for viewing a post feed, post details, and interacting with likes and comments.
- **Consultation_Module**: The set of screens for browsing trainers, viewing trainer profiles, and booking appointments.
- **Notifications_Screen**: The screen displaying a list of notifications using static/mock data.
- **Settings_Module**: The set of screens for updating profile, notification preferences, password changes, and theme toggling.
- **Timer_Controller**: The UI-level timer logic that manages countdown, pause, and resume states for exercise and rest periods.

## Requirements

### Requirement 1: Centralized Theme System

**User Story:** As a developer, I want a single theme source of truth, so that all screens share consistent colors, typography, and component styling without duplication.

#### Acceptance Criteria

1. THE Theme_System SHALL define a light theme and a dark theme in `lib/core/theme` using Material Design 3 `ThemeData` objects with a `ColorScheme` for each mode.
2. THE Theme_System SHALL export a unified color palette, a text style set (headline, title, body, label, caption), and a set of named spacing constants containing at least four values (e.g., xs, sm, md, lg) defined as numeric dp values.
3. THE Flutter_App SHALL apply the Theme_System to the root `MaterialApp` widget so that all descendant screens inherit the defined theme.
4. WHEN the user toggles between light and dark mode in Settings_Module, THE Flutter_App SHALL switch the active `ThemeData` and re-render visible widgets with the new theme without requiring an app restart.
5. THE Theme_System SHALL define reusable component themes for buttons, input fields, cards, and app bars so that all modules render component appearances derived from the Theme_System definitions.
6. THE Theme_System SHALL provide a single barrel export file in `lib/core/theme` that exposes the light theme, dark theme, color palette, text styles, and spacing constants so that other modules can access all theme values through one import.

### Requirement 2: Centralized Routing

**User Story:** As a developer, I want a single router configuration managing all app routes, so that navigation between screens is consistent and maintainable.

#### Acceptance Criteria

1. THE Router SHALL be implemented using the `go_router` package and defined in a single configuration file within `lib/core`.
2. THE Router SHALL define named routes for every Screen in the application, including Auth_Module (login, register, forgot password), Profile_Module (setup, edit), Assessment_Module (each step), Dashboard_Screen, Workout_Module (detail, active session, summary), Exercise_Library (list, detail), Progress_Module (summary, session detail), Community_Module (feed, post detail), Consultation_Module (trainer list, trainer profile, booking form), Notifications_Screen, and Settings_Module (main, notification settings, change password).
3. WHEN a user navigates to a defined route, THE Router SHALL render the corresponding Screen widget with no unhandled exceptions and the screen content visible in the viewport.
4. WHEN a user navigates to an undefined route, THE Router SHALL display a "Page Not Found" Screen with a navigation option to return to the Dashboard_Screen.
5. THE Router SHALL support route parameters for detail screens by accepting path parameters for: exercise identifier (Exercise Detail), post identifier (Post Detail), trainer identifier (Trainer Profile), workout identifier (Workout Detail), and workout session identifier (Progress session detail).
6. WHILE the user is on a primary screen (Dashboard_Screen, Exercise_Library, Progress_Module, Community_Module, Settings_Module), THE Router SHALL display a bottom navigation bar that remains visible and preserves each tab's navigation state independently when switching between tabs.
7. THE Router SHALL define the Dashboard_Screen as the initial route for authenticated users and the Login Screen as the initial route for unauthenticated users.
8. IF an unauthenticated user attempts to navigate to a route outside the Auth_Module, THEN THE Router SHALL redirect the user to the Login Screen.
9. IF an authenticated user attempts to navigate to an Auth_Module route (login, register, forgot password), THEN THE Router SHALL redirect the user to the Dashboard_Screen.

### Requirement 3: Authentication Screens

**User Story:** As a user, I want registration, login, and forgot-password screens, so that I can access the app's authenticated features.

#### Acceptance Criteria

1. THE Auth_Module SHALL provide a Register Screen with input fields for name (maximum 50 characters), email, password (minimum 8 characters), and confirm password, and a submit button.
2. THE Auth_Module SHALL provide a Login Screen with input fields for email and password, a submit button, and a navigation link to the Register Screen and Forgot Password Screen.
3. THE Auth_Module SHALL provide a Forgot Password Screen with an input field for email and a submit button.
4. WHEN the user submits the Register Screen form with a valid email format, a name of at least 1 character, and a password of at least 8 characters matching the confirm password field, THE Auth_Module SHALL invoke the Mock_Repository and navigate to the Profile Setup Screen.
5. WHEN the user submits the Login Screen form with a non-empty email in valid format and a non-empty password, THE Auth_Module SHALL invoke the Mock_Repository and navigate to the Dashboard_Screen.
6. WHEN the user submits any Auth_Module form with empty required fields, THE Auth_Module SHALL display inline validation error messages below each invalid field and prevent form submission.
7. WHEN the user submits the Register Screen with a password and confirm password that do not match, THE Auth_Module SHALL display a validation error below the confirm password field indicating the mismatch.
8. IF the Mock_Repository returns an error response during login, THEN THE Auth_Module SHALL display a snackbar message indicating invalid credentials.
9. IF the Mock_Repository returns an error response during registration, THEN THE Auth_Module SHALL display a snackbar message indicating the registration failure reason.
10. WHEN the user submits the Forgot Password Screen with a valid email format, THE Auth_Module SHALL invoke the Mock_Repository and display a confirmation message indicating that password reset instructions have been sent.
11. WHEN the user submits any Auth_Module email field with a value that does not conform to a standard email format (containing "@" and a domain), THE Auth_Module SHALL display an inline validation error below the email field indicating an invalid email format.

### Requirement 4: Profile Setup and Management Screens

**User Story:** As a user, I want to provide and update my personal and fitness information, so that the app can personalize my experience.

#### Acceptance Criteria

1. THE Profile_Module SHALL provide a Profile Setup Screen with input fields for: name (text, 1–50 characters), age (numeric, 13–120), height (numeric, 50–300 cm), weight (numeric, 20–500 kg), gender, fitness goal, fitness level, workout preference, and workout availability.
2. THE Profile_Module SHALL provide a Profile Edit Screen that pre-populates existing mock profile data and allows updates to all profile fields.
3. WHEN the user submits the Profile Setup Screen with all required fields (name, age, height, weight) filled with valid values and at least one day selected for workout availability, THE Profile_Module SHALL save data to the Mock_Repository and navigate to the Assessment_Module.
4. IF the user submits the Profile Setup Screen with missing or invalid required fields (name empty or exceeding 50 characters, age outside 13–120, height outside 50–300, weight outside 20–500), THEN THE Profile_Module SHALL display inline validation errors below each invalid field and prevent navigation.
5. THE Profile_Module SHALL provide dropdown or selection controls for gender (Male, Female, Other), fitness goal (Lose Weight, Build Muscle, Maintain Fitness, Improve Endurance), fitness level (Beginner, Intermediate, Advanced), and workout preference (Home, Gym, Outdoor).
6. THE Profile_Module SHALL provide a multi-select control for workout availability allowing selection of one or more days of the week (Monday through Sunday).
7. WHEN the user updates profile fields on the Profile Edit Screen and submits, THE Profile_Module SHALL save the updated data to the Mock_Repository and display a confirmation message indicating the profile was updated.
8. IF the user submits the Profile Edit Screen with invalid field values, THEN THE Profile_Module SHALL display inline validation errors and prevent the update from being saved.

### Requirement 5: Fitness Assessment Flow

**User Story:** As a user, I want to complete a guided fitness assessment, so that the app can establish my baseline fitness metrics.

#### Acceptance Criteria

1. THE Assessment_Module SHALL present a multi-step flow consisting of at least three sequential screens: BMI inputs (height in cm, weight in kg), physical information (age, gender, activity level with options: Sedentary, Lightly Active, Moderately Active, Very Active), and goals/experience (fitness goal, years of training experience as numeric input).
2. THE Assessment_Module SHALL display a progress indicator showing the current step number relative to the total number of steps (e.g., "Step 2 of 3" or a progress bar at 66%).
3. WHEN the user completes the final step of the Assessment_Module, THE Assessment_Module SHALL save assessment data to the Mock_Repository and navigate to the Dashboard_Screen.
4. WHEN the user taps the back control on any step after the first, THE Assessment_Module SHALL navigate to the previous step with previously entered data retained.
5. WHEN the user taps the back control on the first step, THE Assessment_Module SHALL navigate back to the Profile Setup Screen or the screen that launched the assessment.
6. WHEN the user submits a step with missing required fields (height and weight on step 1; age and activity level on step 2; fitness goal on step 3), THE Assessment_Module SHALL display inline validation errors and prevent advancement to the next step.
7. THE Assessment_Module SHALL calculate and display a BMI value (weight in kg divided by height in meters squared, rounded to one decimal place) in real-time as the user enters or modifies height and weight values on the BMI inputs step.

### Requirement 6: Dashboard Screen

**User Story:** As a user, I want a dashboard showing my daily workout, weekly progress, goals, and streak, so that I can see my fitness status at a glance.

#### Acceptance Criteria

1. THE Dashboard_Screen SHALL display a "Today's Workout" card showing the workout name, estimated duration in minutes, and number of exercises from mock data.
2. THE Dashboard_Screen SHALL display a weekly progress section showing completed workout days out of planned days for the current week using mock data.
3. THE Dashboard_Screen SHALL display a goal progress indicator as a numeric percentage (0–100) with a visible progress bar representing progress toward the user's fitness goal from mock data.
4. THE Dashboard_Screen SHALL display a workout streak counter showing the number of consecutive workout days from mock data, displaying "0" when no streak exists.
5. WHEN the user taps the "Today's Workout" card, THE Router SHALL navigate to the Workout_Module workout detail screen.
6. WHEN the user taps the weekly progress section, THE Router SHALL navigate to the Progress_Module.
7. IF the Mock_Repository provides no scheduled workout for the current day, THEN THE Dashboard_Screen SHALL display an empty state message within the "Today's Workout" card area indicating no workout is planned, and the card SHALL NOT be tappable for navigation.

### Requirement 7: Workout Screens

**User Story:** As a user, I want to view my workout exercises and control the session with play/pause/skip functionality and timers, so that I can follow along during exercise.

#### Acceptance Criteria

1. THE Workout_Module SHALL provide a Workout Detail Screen listing all exercises in the current workout session, showing exercise name, sets, reps or duration, and a thumbnail placeholder for each exercise, with a "Start Workout" button that navigates to the Workout Active Screen beginning at the first exercise.
2. THE Workout_Module SHALL provide a Workout Active Screen displaying the current exercise name, an exercise timer counting down the prescribed duration, and controls for start, pause, resume, skip, and complete.
3. WHEN the user taps the start control, THE Timer_Controller SHALL begin counting down the exercise duration and update the displayed time every second.
4. WHEN the user taps the pause control during an active timer, THE Timer_Controller SHALL pause the countdown and the resume control SHALL become available.
5. WHEN the user taps the skip control and the current exercise is not the last in the list, THE Workout_Module SHALL advance to the next exercise in the list, resetting the Timer_Controller for the new exercise duration.
6. WHEN the user taps the skip control on the last exercise in the list, THE Workout_Module SHALL navigate to the workout summary screen.
7. WHEN an exercise timer reaches zero, THE Workout_Module SHALL display a rest timer screen counting down a rest period between 10 and 120 seconds (configurable per exercise in mock data, defaulting to 30 seconds) before advancing to the next exercise.
8. WHEN the user taps the skip control during the rest timer, THE Workout_Module SHALL cancel the remaining rest period and immediately advance to the next exercise.
9. WHEN the user taps the complete control or finishes the last exercise, THE Workout_Module SHALL display a workout summary screen showing total duration, exercises completed, and a congratulatory message.
10. THE Timer_Controller SHALL operate entirely in the UI layer using Dart timers without requiring backend communication.

### Requirement 8: Exercise Library Screens

**User Story:** As a user, I want to browse exercises by category and view detailed instructions, so that I can learn proper form and find new exercises.

#### Acceptance Criteria

1. THE Exercise_Library SHALL provide a List Screen displaying exercises from the Mock_Repository with each item showing the exercise name, target muscle group, difficulty level (Beginner, Intermediate, Advanced), and an image placeholder.
2. THE Exercise_Library SHALL provide filter controls allowing the user to filter exercises by muscle group and difficulty level, with the ability to select multiple muscle groups simultaneously.
3. THE Exercise_Library SHALL provide a search input allowing the user to filter exercises by name using case-insensitive substring matching, updating results as the user types.
4. WHEN the user taps an exercise item in the list, THE Router SHALL navigate to the Exercise Detail Screen passing the exercise identifier.
5. THE Exercise_Library SHALL provide a Detail Screen displaying: exercise name, target muscle group, step-by-step instructions (as a numbered list), required equipment (or "No equipment" if none), difficulty level, and an image placeholder.
6. WHEN the Exercise_Library List Screen loads, THE Mock_Repository SHALL provide at least ten sample exercises spanning at least three different muscle groups.
7. IF no exercises match the current filter and search criteria, THEN THE Exercise_Library SHALL display an empty state message indicating no exercises found.

### Requirement 9: Progress Tracking Screens

**User Story:** As a user, I want to view my workout history, streaks, weight changes, and weekly statistics in chart form, so that I can track my fitness journey.

#### Acceptance Criteria

1. THE Progress_Module SHALL provide a summary screen displaying: total completed workouts, current streak, longest streak, and current weight from mock data.
2. THE Progress_Module SHALL display a weight history chart plotting at least five mock weight data points over time with a labeled date axis and a value axis indicating the unit (kg).
3. THE Progress_Module SHALL display a BMI history chart plotting at least five mock BMI data points over time with a labeled date axis and a value axis.
4. THE Progress_Module SHALL display a weekly statistics section showing workouts completed per week for the last four weeks using mock data.
5. THE Progress_Module SHALL display a list of at least five recently completed workouts showing workout name, date, duration, and exercise count from mock data.
6. WHEN the user taps a completed workout entry, THE Progress_Module SHALL navigate to a detail view showing the exercises performed in that session including exercise name, sets completed, and reps or duration.

### Requirement 10: Community Feed Screens

**User Story:** As a user, I want to browse community posts, view details, and interact with likes and comments, so that I can engage with other users.

#### Acceptance Criteria

1. THE Community_Module SHALL provide a Feed Screen displaying a scrollable list of posts from the Mock_Repository, each showing author name, post content truncated to a maximum of 150 characters followed by an ellipsis if the content exceeds that length, like count, comment count, and timestamp displayed in relative format (e.g., "2 hours ago", "3 days ago").
2. WHEN the user taps a post in the Feed Screen, THE Router SHALL navigate to the Post Detail Screen passing the post identifier.
3. THE Community_Module SHALL provide a Post Detail Screen displaying the full post content, author name, timestamp, like count, a list of comments (each showing comment author name and comment text), and a comment input field with a maximum length of 500 characters.
4. WHEN the user taps the like button on a post, THE Community_Module SHALL toggle the like state between liked and unliked, increment or decrement the displayed like count by one accordingly, and visually indicate the current like state (e.g., filled icon for liked, outlined icon for unliked) without waiting for Mock_Repository confirmation.
5. WHEN the user submits a comment via the comment input field with at least one non-whitespace character, THE Community_Module SHALL append the new comment to the top of the displayed comment list showing the current user as author and clear the input field.
6. IF the user attempts to submit a comment via the comment input field while the field is empty or contains only whitespace, THEN THE Community_Module SHALL not add a comment and SHALL display a validation message indicating that comment text is required.
7. THE Mock_Repository SHALL provide at least five sample posts, each with at least two comments for the Community_Module.

### Requirement 11: Consultation Screens

**User Story:** As a user, I want to browse trainers, view their profiles, and book consultations, so that I can get professional fitness guidance.

#### Acceptance Criteria

1. THE Consultation_Module SHALL provide a Trainer List Screen displaying available trainers from the Mock_Repository, each showing trainer name, specialization, rating (numeric, 1–5), and an avatar placeholder.
2. WHEN the user taps a trainer in the list, THE Router SHALL navigate to the Trainer Profile Screen passing the trainer identifier.
3. THE Consultation_Module SHALL provide a Trainer Profile Screen displaying: trainer name, bio, specialization, rating, experience years, available time slots, an avatar placeholder, and a "Book Consultation" button that navigates to the Booking Form Screen.
4. THE Consultation_Module SHALL provide a Booking Form Screen with fields for: selected date (no earlier than the current date), selected time slot (from the trainer's available slots), consultation type (in-person, video call), and optional notes (maximum 500 characters).
5. WHEN the user submits the Booking Form with all required fields filled (date, time slot, consultation type), THE Consultation_Module SHALL save the booking to the Mock_Repository and display a confirmation message.
6. WHEN the user submits the Booking Form with missing required fields (date, time slot, consultation type), THE Consultation_Module SHALL display inline validation errors below each missing field.
7. THE Mock_Repository SHALL provide at least three sample trainers each with at least two available time slots for the Consultation_Module.

### Requirement 12: Notifications Screen

**User Story:** As a user, I want to view a list of notifications, so that I can stay informed about app activity and reminders.

#### Acceptance Criteria

1. THE Notifications_Screen SHALL display a scrollable list of notifications from the Mock_Repository ordered by timestamp descending (newest first), each showing a title (maximum 80 characters, truncated with ellipsis if exceeded), description (maximum 200 characters, truncated with ellipsis if exceeded), relative timestamp (e.g., "2 min ago", "1 hour ago", "3 days ago"), and read/unread indicator.
2. WHEN the user taps an unread notification item, THE Notifications_Screen SHALL mark the notification as read in the Mock_Repository and update the visual indicator from unread to read state.
3. IF no notifications are available when the Notifications_Screen loads, THEN THE Notifications_Screen SHALL display a centered empty state message indicating that there are no notifications, with an icon or illustration placeholder.
4. THE Mock_Repository SHALL provide at least five sample notifications of varying types (workout reminder, achievement, community interaction, system update) with at least two marked as unread.
5. THE Notifications_Screen SHALL visually distinguish between read and unread notifications using different background colors or text weight, applied consistently across the entire notification item row.
6. WHEN the user taps a notification item that is already marked as read, THE Notifications_Screen SHALL remain in the current state without modifying the notification's read status.

### Requirement 13: Settings Screens

**User Story:** As a user, I want to manage my account preferences, notification settings, password, and app theme, so that I can customize my experience.

#### Acceptance Criteria

1. THE Settings_Module SHALL provide a Settings Main Screen with navigation options for: Edit Profile, Notification Settings, and Change Password, and an inline theme toggle switch visible on the Settings Main Screen.
2. THE Settings_Module SHALL provide a Notification Settings Screen with toggles for: workout reminders, community updates, achievement alerts, and consultation reminders, with all toggles defaulting to enabled on first load and persisting their state to the Mock_Repository across screen visits.
3. THE Settings_Module SHALL provide a Change Password Screen with fields for: current password, new password (minimum 8 characters), and confirm new password (minimum 8 characters).
4. WHEN the user submits the Change Password Screen with any required field empty, THE Settings_Module SHALL display inline validation errors indicating which fields are required.
5. WHEN the user submits the Change Password Screen with a new password and confirm password that do not match, THE Settings_Module SHALL display a validation error indicating the mismatch.
6. WHEN the user submits the Change Password Screen with all fields filled and new password matching confirm password, THE Settings_Module SHALL invoke the Mock_Repository, display a success confirmation message, and clear the form fields.
7. WHEN the user toggles the theme switch, THE Theme_System SHALL switch between light and dark mode and persist the selection using local storage.
8. THE Settings_Module Edit Profile Screen SHALL reuse the Profile_Module Profile Edit Screen to maintain a single implementation for profile editing.

### Requirement 14: Mock Data Layer

**User Story:** As a developer, I want mock repositories providing placeholder data for all modules, so that all screens are functional and navigable without a backend.

#### Acceptance Criteria

1. THE Mock_Repository SHALL provide mock data classes for: User, UserProfile, Exercise, Workout, WorkoutSession, Post, Comment, Trainer, Booking, Notification, and ProgressRecord.
2. THE Mock_Repository SHALL be defined as injectable providers (using Riverpod, Provider, or a similar state management approach) so that screens access data through a consistent interface.
3. THE Mock_Repository SHALL return data via simulated async calls with artificial delays between 200 milliseconds and 500 milliseconds to mirror real API behavior patterns.
4. WHEN a Screen requests data from the Mock_Repository, THE Mock_Repository SHALL return placeholder data where every data-bound UI field receives a non-null, non-empty value so that no Screen displays blank, null, or placeholder-missing content.
5. THE Mock_Repository SHALL support basic CRUD operations (create, read, update, delete) on in-memory collections for modules that modify data (Profile_Module, Community_Module, Consultation_Module, Notifications_Screen).
6. IF a CRUD update or delete operation targets a record identifier that does not exist in the in-memory collection, THEN THE Mock_Repository SHALL return an error result indicating the record was not found without modifying the collection.
7. THE Mock_Repository SHALL provide minimum dataset sizes of: 10 exercises across at least 3 muscle groups, 3 workouts each containing at least 4 exercises, 5 posts each with at least 2 comments, 3 trainers with available time slots, 5 notifications of varying types, and 5 progress records spanning at least 4 weeks.
8. THE Mock_Repository interface SHALL be structured so that swapping mock implementations for real API implementations requires changes only in the data layer without modifying Screen widgets.

### Requirement 15: Responsive Layout

**User Story:** As a user, I want the app to display correctly across common Android screen sizes, so that I have a usable experience on any supported device.

#### Acceptance Criteria

1. THE Flutter_App SHALL render all screens without overflow errors on screen widths ranging from 360dp to 430dp and screen heights ranging from 640dp to 860dp (covering common Android phone sizes).
2. THE Flutter_App SHALL use scrollable containers for any content area whose total content height exceeds the available viewport height, ensuring all content remains accessible via vertical scrolling.
3. THE Flutter_App SHALL reference the Theme_System's defined text styles and spacing constants for all margins, padding, gaps, and widget sizing rather than fixed pixel values, so that layout adapts consistently across supported screen dimensions.
4. WHEN a screen contains a form with two or more input fields and the software keyboard is displayed, THE Flutter_App SHALL scroll the active input field into the visible area above the keyboard.
5. THE Flutter_App SHALL render all interactive elements (buttons, input fields, toggles, list item tap targets) with a minimum touch target size of 48x48dp.
