# Requirements Document

## Introduction

This document specifies the requirements for adding offline support, profile customization, and workout scheduling with a separated exercise library to SyncroFit. The feature set enables users to use the app without continuous internet connectivity, fully customize their profile through the Laravel backend, and navigate between a general exercise library and personalized workout recommendations via a tabbed interface with scheduling capabilities.

## Glossary

- **Sync_Engine**: The Flutter-side component responsible for detecting connectivity changes, queuing mutations made offline, and reconciling local data with the Laravel backend when connectivity returns.
- **Local_Cache**: The on-device persistent storage (SQLite or equivalent) that stores exercises, workouts, profile data, and progress records for offline access.
- **Connectivity_Monitor**: The component that observes network availability and emits connectivity state changes to the rest of the application.
- **Profile_Service**: The combined Flutter provider and Laravel controller logic responsible for reading, creating, and updating the user's profile preferences.
- **Exercise_Library_Tab**: The UI tab displaying all available exercises with filtering and search capabilities.
- **Recommendations_Tab**: The UI tab displaying personalized workout recommendations and the user's weekly workout plan.
- **Workout_Scheduler**: The component that assigns workouts to specific days and presents the user's weekly workout schedule.
- **Conflict_Resolver**: The component that determines which version of data wins when the same record has been modified both locally and on the server while offline.
- **Sync_Queue**: The ordered list of pending mutations (creates, updates, deletes) performed offline that are awaiting synchronization with the backend.

## Requirements

### Requirement 1: Connectivity Monitoring

**User Story:** As a user, I want the app to detect when I lose or regain internet connectivity, so that it can seamlessly switch between online and offline modes without interrupting my workflow.

#### Acceptance Criteria

1. THE Connectivity_Monitor SHALL emit a connectivity state (online or offline) observable by all application components.
2. WHEN network connectivity transitions from online to offline, THE Connectivity_Monitor SHALL notify the Sync_Engine within 5 seconds of the change.
3. WHEN network connectivity transitions from offline to online, THE Connectivity_Monitor SHALL notify the Sync_Engine within 5 seconds of the change.
4. THE Connectivity_Monitor SHALL verify actual server reachability rather than relying solely on device network interface status.

### Requirement 2: Local Data Caching

**User Story:** As a user, I want my exercises, workouts, profile, and progress data cached locally, so that I can browse and interact with the app even without internet.

#### Acceptance Criteria

1. WHEN the application fetches exercises from the backend, THE Local_Cache SHALL persist the exercise data to on-device storage.
2. WHEN the application fetches workouts and recommendations from the backend, THE Local_Cache SHALL persist the workout data to on-device storage.
3. WHEN the application fetches the user profile from the backend, THE Local_Cache SHALL persist the profile data to on-device storage.
4. WHEN the application fetches progress records from the backend, THE Local_Cache SHALL persist the progress data to on-device storage.
5. WHILE the device is offline, THE Local_Cache SHALL serve cached data to all repository read operations.
6. THE Local_Cache SHALL store a last-synced timestamp for each data category (exercises, workouts, profile, progress).

### Requirement 3: Offline Mutation Queuing

**User Story:** As a user, I want to be able to complete workouts, update my profile, and log progress while offline, so that I do not lose any data when I am without connectivity.

#### Acceptance Criteria

1. WHILE the device is offline, WHEN the user performs a write operation (create, update, or delete), THE Sync_Queue SHALL enqueue the mutation with a timestamp and operation type.
2. THE Sync_Queue SHALL persist enqueued mutations to on-device storage so they survive app restarts.
3. THE Sync_Queue SHALL maintain the chronological order of mutations as they were performed by the user.
4. WHILE the device is offline, THE application SHALL apply mutations to the Local_Cache immediately so the user sees their changes reflected in the UI.

### Requirement 4: Data Synchronization on Reconnection

**User Story:** As a user, I want my offline changes to sync automatically when I regain connectivity, so that my data is consistent across devices.

#### Acceptance Criteria

1. WHEN connectivity transitions from offline to online, THE Sync_Engine SHALL process all pending mutations from the Sync_Queue in chronological order.
2. WHEN a mutation is successfully synced to the backend, THE Sync_Engine SHALL remove that mutation from the Sync_Queue.
3. IF a mutation fails due to a server validation error (HTTP 422), THEN THE Sync_Engine SHALL mark the mutation as failed and notify the user.
4. IF a mutation fails due to a transient error (HTTP 5xx or network timeout), THEN THE Sync_Engine SHALL retry the mutation with exponential backoff up to 3 attempts.
5. WHEN all pending mutations are processed, THE Sync_Engine SHALL refresh the Local_Cache with the latest data from the backend.

### Requirement 5: Conflict Resolution

**User Story:** As a user, I want conflicts between my offline changes and server changes to be resolved predictably, so that I do not lose important data.

#### Acceptance Criteria

1. THE Conflict_Resolver SHALL use a last-write-wins strategy based on mutation timestamps.
2. IF a conflict is detected during sync (server record has a newer updated_at than the local mutation timestamp), THEN THE Conflict_Resolver SHALL keep the server version and discard the local mutation.
3. WHEN a conflict causes a local mutation to be discarded, THE Sync_Engine SHALL notify the user that their offline change was overridden by a newer server update.
4. THE Sync_Engine SHALL include the local updated_at timestamp in sync requests so the backend can detect conflicts.

### Requirement 6: Profile Customization via Backend

**User Story:** As a user, I want to fully customize my profile (fitness goals, availability days, workout preference, fitness level, and physical metrics), so that the app tailors recommendations to my current situation.

#### Acceptance Criteria

1. THE Profile_Service SHALL allow the user to update the following fields independently: name, age, height_cm, weight_kg, gender, fitness_goal, fitness_level, workout_preference, and availability_days.
2. WHEN the user updates any profile field, THE Profile_Service SHALL send a PATCH request to the Laravel backend with only the changed fields.
3. WHEN the backend receives a profile update, THE Profile_Service SHALL recompute BMI if height_cm or weight_kg changed.
4. WHEN the user updates their profile while offline, THE Profile_Service SHALL apply the change to the Local_Cache and enqueue the mutation in the Sync_Queue.
5. THE Profile_Service SHALL validate profile fields on the client side before submitting (age between 13 and 120, height_cm between 50 and 300, weight_kg between 20 and 500).

### Requirement 7: Profile Edit Screen

**User Story:** As a user, I want a dedicated profile editing screen where I can modify all my profile settings, so that I can easily adjust my fitness parameters as my goals change.

#### Acceptance Criteria

1. THE application SHALL display a profile edit screen accessible from the existing profile or settings area.
2. THE profile edit screen SHALL present all editable profile fields: name, age, height, weight, gender, fitness goal, fitness level, workout preference, and availability days.
3. WHEN the user submits profile changes, THE application SHALL display a loading indicator until the save operation completes.
4. IF the profile update fails with a validation error, THEN THE application SHALL display field-specific error messages next to the relevant inputs.
5. WHEN the profile update succeeds, THE application SHALL navigate back to the profile view and display the updated information.

### Requirement 8: Separated Exercise Library and Recommendations Tabs

**User Story:** As a user, I want the exercise library and my personalized recommendations shown in separate tabs, so that I can browse exercises independently from my assigned workout plan.

#### Acceptance Criteria

1. THE application SHALL display a tabbed interface with two tabs: Exercise_Library_Tab and Recommendations_Tab.
2. WHEN the user selects the Exercise_Library_Tab, THE application SHALL display all available exercises with existing filtering and search capabilities.
3. WHEN the user selects the Recommendations_Tab, THE application SHALL display the user's current personalized workout plan organized by day of the week.
4. THE application SHALL preserve the selected tab and scroll position when navigating away and returning to the screen.
5. THE Exercise_Library_Tab SHALL retain all existing functionality: filtering by muscle group, filtering by difficulty, and search by name.

### Requirement 9: Workout Scheduling

**User Story:** As a user, I want to see my weekly workout schedule with upcoming workouts assigned to specific days, so that I know exactly when and what to train.

#### Acceptance Criteria

1. THE Workout_Scheduler SHALL display a weekly view showing workouts assigned to each day based on the user's availability_days and current recommendation.
2. WHEN a recommendation is generated, THE Workout_Scheduler SHALL map each workout in the plan to the corresponding day_of_week field.
3. THE Workout_Scheduler SHALL visually distinguish between past completed workouts, today's workout, and upcoming scheduled workouts.
4. WHEN the user taps a scheduled workout, THE application SHALL navigate to the workout detail screen showing exercises, sets, reps, and rest periods.
5. IF no recommendation exists for the user, THEN THE Workout_Scheduler SHALL display a prompt to generate a workout plan.

### Requirement 10: Offline-Aware UI Indicators

**User Story:** As a user, I want visual indicators when I am offline or when data is pending sync, so that I understand the current state of my data.

#### Acceptance Criteria

1. WHILE the device is offline, THE application SHALL display a persistent offline indicator visible on all screens.
2. WHILE mutations are pending in the Sync_Queue, THE application SHALL display a sync-pending indicator showing the count of pending changes.
3. WHEN synchronization completes successfully, THE application SHALL briefly display a sync-complete confirmation.
4. WHEN a sync conflict or failure occurs, THE application SHALL display a notification describing which data was affected.

### Requirement 11: Cache Freshness and Invalidation

**User Story:** As a user, I want the app to fetch fresh data when I am online but not re-download unchanged data unnecessarily, so that the app is both current and data-efficient.

#### Acceptance Criteria

1. WHEN the device is online and the Local_Cache data is older than 15 minutes, THE Sync_Engine SHALL refresh the cache from the backend.
2. WHILE the device is online and cached data is less than 15 minutes old, THE application SHALL serve data from the Local_Cache without making a network request.
3. THE application SHALL allow the user to manually trigger a data refresh via a pull-to-refresh gesture.
4. WHEN a manual refresh is triggered, THE Sync_Engine SHALL fetch fresh data from the backend regardless of cache age.
