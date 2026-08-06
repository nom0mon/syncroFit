# Implementation Plan: Offline Support and UI Enhancements

## Overview

This plan implements offline support (SQLite caching, connectivity monitoring, sync engine), profile customization (edit screen, PATCH semantics), tabbed exercise/recommendations UI, workout scheduling, and offline-aware UI indicators for SyncroFit. Tasks follow a vertical-slice approach grouped by component, with each slice building incrementally on prior work.

## Tasks

- [x] 1. Foundation — Dependencies, SQLite schema, DAOs, database initialization
  - [x] 1.1 Add dependencies and create data models
    - Add `sqflite`, `sqflite_common_ffi_web`, `connectivity_plus`, `path_provider`, and `uuid` to `pubspec.yaml`
    - Create `lib/shared/models/sync_mutation.dart` with `SyncMutation`, `SyncStatus` enum
    - Create `lib/shared/models/cache_metadata.dart` with `CacheMetadata` class
    - Create `lib/shared/models/scheduled_workout.dart` with `ScheduledWorkout` class and `DayOfWeek` enum
    - Add `DateTime? updatedAt` field to existing `UserProfile` model
    - Export new models from `lib/shared/models/models.dart`
    - _Requirements: 3.1, 3.2, 5.4, 9.2_

  - [x] 1.2 Create SQLite database schema and initialization
    - Create `lib/data/local/local_database.dart` with `LocalDatabase` abstract class and `LocalDatabaseImpl`
    - Implement `initialize()` that creates all tables from the design schema (exercises, workouts, workout_sessions, user_profile, progress_records, sync_queue, cache_metadata)
    - Create `lib/data/local/database_provider.dart` with a Riverpod provider for `LocalDatabase`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.2_

  - [x] 1.3 Create DAO classes for each entity type
    - Create `lib/data/local/daos/exercise_dao.dart` — `getAll()`, `getById()`, `upsertAll()`, `upsert()`, `deleteById()`
    - Create `lib/data/local/daos/workout_dao.dart` — `getAll()`, `getById()`, `upsertAll()`, `upsert()`, `deleteById()`
    - Create `lib/data/local/daos/profile_dao.dart` — `get()`, `upsert()`, `delete()`
    - Create `lib/data/local/daos/progress_dao.dart` — `getAll()`, `upsert()`, `upsertAll()`, `deleteById()`
    - Create `lib/data/local/daos/sync_queue_dao.dart` — `enqueue()`, `getPending()`, `markCompleted()`, `markFailed()`, `incrementRetry()`, `pendingCount()`, `clear()`
    - Create `lib/data/local/daos/cache_metadata_dao.dart` — `getLastSynced()`, `updateLastSynced()`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6, 3.1, 3.2_

- [x] 2. Connectivity — ConnectivityMonitor and Riverpod provider
  - [x] 2.1 Implement ConnectivityMonitor
    - Create `lib/core/network/connectivity_monitor.dart` with `ConnectivityMonitor` abstract class and `ConnectivityStatus` enum
    - Create `lib/core/network/connectivity_monitor_impl.dart` implementing the monitor
    - Listen to `Connectivity().onConnectivityChanged`; debounce transitions by 2 seconds
    - Validate reachability by pinging `GET /api/health` endpoint
    - Emit `ConnectivityStatus.online` or `ConnectivityStatus.offline` on the `statusStream`
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 2.2 Create ConnectivityMonitor Riverpod provider and ConnectivityNotifier
    - Create `lib/core/network/connectivity_provider.dart`
    - Expose `connectivityMonitorProvider` (singleton)
    - Create `ConnectivityNotifier` StateNotifier that watches the monitor stream and exposes current status
    - Expose `connectivityStatusProvider` for UI consumption
    - _Requirements: 1.1_

- [x] 3. Local Caching — CachingRepository implementations
  - [x] 3.1 Implement CachingExerciseRepository
    - Create `lib/data/caching/caching_exercise_repository.dart` implementing `ExerciseRepository`
    - Online: fetch from remote, persist to DAO, update cache metadata; if cache < 15 min old, serve from cache
    - Offline: serve from DAO
    - _Requirements: 2.1, 2.5, 11.1, 11.2_

  - [x] 3.2 Implement CachingWorkoutRepository
    - Create `lib/data/caching/caching_workout_repository.dart` implementing `WorkoutRepository`
    - Online: fetch from remote, persist to DAO, update cache metadata; if cache < 15 min old, serve from cache
    - Offline: serve from DAO; queue mutations to SyncQueue
    - _Requirements: 2.2, 2.5, 3.1, 3.4, 11.1, 11.2_

  - [x] 3.3 Implement CachingProfileRepository
    - Create `lib/data/caching/caching_profile_repository.dart` implementing `ProfileRepository`
    - Online: fetch from remote, persist to DAO, update cache metadata
    - Offline: serve from DAO; queue profile mutations to SyncQueue with PATCH payload (only dirty fields)
    - Include `updatedAt` timestamp in mutations for conflict resolution
    - _Requirements: 2.3, 2.5, 3.1, 3.4, 6.2, 6.4, 11.1, 11.2_

  - [x] 3.4 Implement CachingProgressRepository
    - Create `lib/data/caching/caching_progress_repository.dart` implementing `ProgressRepository`
    - Online: fetch from remote, persist to DAO, update cache metadata; if cache < 15 min old, serve from cache
    - Offline: serve from DAO; queue mutations to SyncQueue
    - _Requirements: 2.4, 2.5, 3.1, 3.4, 11.1, 11.2_

- [x] 4. Checkpoint — Foundation and caching layers
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Sync Engine — SyncQueue, SyncEngine, ConflictResolver
  - [x] 5.1 Implement SyncQueue service
    - Create `lib/data/sync/sync_queue.dart` with `SyncQueue` abstract class
    - Create `lib/data/sync/sync_queue_impl.dart` wrapping `SyncQueueDao`
    - Implement `enqueue()`, `getPending()` (ordered by `createdAt`), `markCompleted()`, `markFailed()`, `incrementRetry()`, `pendingCount()`, `clear()`
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 5.2 Implement ConflictResolver
    - Create `lib/data/sync/conflict_resolver.dart`
    - Implement last-write-wins: `shouldApplyLocal()` returns true iff `localMutationTimestamp.isAfter(serverUpdatedAt)`
    - _Requirements: 5.1, 5.2_

  - [x] 5.3 Implement SyncEngine
    - Create `lib/data/sync/sync_engine.dart` with abstract `SyncEngine` class
    - Create `lib/data/sync/sync_engine_impl.dart`
    - Listen to `ConnectivityMonitor.statusStream`; on `online` transition call `processQueue()`
    - `processQueue()`: iterate pending mutations in order, POST/PATCH/DELETE to backend, use ConflictResolver for 409 responses, retry transient errors (5xx/timeout) with exponential backoff (2s, 4s, 8s, max 3 attempts), mark 422 as failed
    - After queue processed, call `refreshCaches()` to pull latest data from backend
    - Emit `SyncEvent` stream (started, completed, conflictDetected, mutationFailed)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.4_

  - [x] 5.4 Create SyncEngine Riverpod providers
    - Create `lib/data/sync/sync_providers.dart`
    - Expose `syncQueueProvider`, `conflictResolverProvider`, `syncEngineProvider`
    - Create `SyncStatusNotifier` exposing sync events and pending count for UI
    - _Requirements: 4.1, 10.2, 10.3, 10.4_

- [x] 6. Profile Customization — Edit screen, PATCH support, offline-aware updates
  - [x] 6.1 Create ProfileEditNotifier with client-side validation
    - Create `lib/features/profile/providers/profile_edit_notifier.dart`
    - Implement `ProfileEditState` with `dirtyFields`, `fieldErrors`, `isSaving`, `isSuccess`
    - Validate: age [13, 120], height_cm [50, 300], weight_kg [20, 500], name non-empty
    - On save: build PATCH payload from dirty fields only; if online → PATCH to backend; if offline → cache + enqueue
    - _Requirements: 6.1, 6.2, 6.4, 6.5_

  - [x] 6.2 Create Profile Edit Screen UI
    - Create `lib/features/profile/screens/profile_edit_screen.dart`
    - Form fields for: name, age, height, weight, gender (dropdown), fitness_goal (dropdown), fitness_level (dropdown), workout_preference (dropdown), availability_days (multi-select chips)
    - Display inline field-specific error messages below each input
    - Show loading indicator during save; navigate back on success
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 6.3 Add route and navigation for profile edit screen
    - Register profile edit route in `lib/core/router/app_router.dart`
    - Add edit button/link to existing profile screen that navigates to profile edit
    - _Requirements: 7.1_

- [x] 7. Tabbed UI — Exercise library and recommendations tabs
  - [x] 7.1 Create ExerciseAndRecommendationsScreen with TabBar
    - Create `lib/features/exercise_library/screens/exercise_and_recommendations_screen.dart`
    - Use `DefaultTabController` with 2 tabs: "Exercise Library" and "Recommendations"
    - Preserve tab selection and scroll position across navigation
    - _Requirements: 8.1, 8.4_

  - [x] 7.2 Refactor existing exercise list into ExerciseLibraryTab
    - Create `lib/features/exercise_library/widgets/exercise_library_tab.dart`
    - Extract current `ExerciseListScreen` content (filter chips, search bar, exercise list) into this tab widget
    - Retain all existing filtering (muscle group, difficulty) and search functionality
    - _Requirements: 8.2, 8.5_

  - [x] 7.3 Create RecommendationsTab with WorkoutScheduler
    - Create `lib/features/exercise_library/widgets/recommendations_tab.dart`
    - Display the user's personalized workout plan organized by day of the week
    - Include the `WorkoutSchedulerWidget` (implemented in next task group)
    - Show empty state prompt if no recommendation exists
    - _Requirements: 8.3, 9.5_

  - [x] 7.4 Update navigation to use tabbed screen
    - Update route in `lib/core/router/app_router.dart` to point to `ExerciseAndRecommendationsScreen` instead of old `ExerciseListScreen`
    - Ensure deep-links and GoRouter state preservation work correctly
    - _Requirements: 8.1, 8.4_

- [x] 8. Workout Scheduler — Weekly schedule widget and visual states
  - [x] 8.1 Create WorkoutScheduler provider and logic
    - Create `lib/features/workout/providers/workout_scheduler_provider.dart`
    - Map recommendations to `availability_days` producing `List<ScheduledWorkout>`
    - Determine completion status for each day (past/completed, today/active, upcoming)
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 8.2 Create WorkoutSchedulerWidget UI
    - Create `lib/features/workout/widgets/workout_scheduler_widget.dart`
    - Display Mon–Sun horizontal row/grid showing workout assignments
    - Visual distinction: grey/checkmark for past completed, highlighted for today, standard for upcoming
    - Tapping a day navigates to workout detail screen
    - If no recommendation, show "Generate Plan" prompt
    - _Requirements: 9.1, 9.3, 9.4, 9.5_

- [x] 9. Offline UI Indicators — Banner, badge, toast, conflict notifications
  - [x] 9.1 Create OfflineIndicator banner widget
    - Create `lib/shared/widgets/offline_indicator.dart`
    - Persistent banner shown at top/bottom of screen when device is offline
    - Watches `connectivityStatusProvider` and shows/hides automatically
    - _Requirements: 10.1_

  - [x] 9.2 Create SyncPendingBadge and sync status widgets
    - Create `lib/shared/widgets/sync_pending_badge.dart`
    - Show count of pending mutations from `SyncStatusNotifier`
    - Create sync-complete toast that displays briefly after successful sync
    - Create conflict notification snackbar for sync failures/overrides
    - _Requirements: 10.2, 10.3, 10.4_

  - [x] 9.3 Integrate offline indicators into app shell
    - Add `OfflineIndicator` to the app's scaffold/shell so it appears on all screens
    - Add `SyncPendingBadge` to the app bar or navigation area
    - Wire toast/snackbar triggers to `SyncEngine.syncEvents` stream
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [x] 10. Checkpoint — All features implemented
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Property Tests — All 10 correctness properties from the design
  - [-] 11.1 Write property test: Sync queue preserves chronological order
    - **Property 1: Sync queue preserves chronological order**
    - **Validates: Requirements 3.3**
    - File: `test/properties/sync_queue_properties_test.dart`
    - For any sequence of mutations with distinct timestamps, `getPending()` returns them sorted by `createdAt` ascending

  - [x] 11.2 Write property test: Offline mutations reflected in local cache
    - **Property 2: Offline mutations are reflected in local cache immediately**
    - **Validates: Requirements 3.4**
    - File: `test/properties/sync_queue_properties_test.dart`
    - For any write while offline, reading the same entity from cache returns the mutated value

  - [-] 11.3 Write property test: Sync queue round-trip persistence
    - **Property 3: Sync queue round-trip persistence**
    - **Validates: Requirements 3.2**
    - File: `test/properties/sync_queue_properties_test.dart`
    - Enqueue then retrieve → mutation fields are preserved through serialization

  - [x] 11.4 Write property test: Conflict resolution deterministic last-write-wins
    - **Property 4: Conflict resolution is deterministic — last-write-wins**
    - **Validates: Requirements 5.1, 5.2**
    - File: `test/properties/conflict_resolver_properties_test.dart`
    - `shouldApplyLocal()` returns true iff `localTimestamp.isAfter(serverTimestamp)`

  - [-] 11.5 Write property test: Successful sync removes mutation from queue
    - **Property 5: Successful sync removes mutation from queue**
    - **Validates: Requirements 4.2**
    - File: `test/properties/sync_queue_properties_test.dart`
    - After `markCompleted()`, `getPending()` no longer contains that mutation

  - [-] 11.6 Write property test: Profile validation rejects out-of-range values
    - **Property 6: Profile validation rejects out-of-range values**
    - **Validates: Requirements 6.5**
    - File: `test/properties/profile_validation_properties_test.dart`
    - For any age outside [13,120], height outside [50,300], weight outside [20,500] → validation fails with field error

  - [-] 11.7 Write property test: Profile PATCH sends only changed fields
    - **Property 7: Profile PATCH sends only changed fields**
    - **Validates: Requirements 6.2**
    - File: `test/properties/profile_validation_properties_test.dart`
    - For any subset of modified fields, PATCH payload contains exactly those fields

  - [~] 11.8 Write property test: Cache freshness triggers refresh
    - **Property 8: Cache freshness — stale data triggers refresh**
    - **Validates: Requirements 11.1, 11.2**
    - File: `test/properties/cache_freshness_properties_test.dart`
    - If `lastSyncedAt` > 15 min ago and online → remote is called; if < 15 min → cache served

  - [~] 11.9 Write property test: Exercise filtering preserves existing behavior
    - **Property 9: Exercise filtering preserves existing behavior**
    - **Validates: Requirements 8.5**
    - File: `test/properties/exercise_filter_properties_test.dart`
    - For any filter combo, results are subset matching ALL criteria (AND across types, OR within muscle groups)

  - [~] 11.10 Write property test: Workout scheduler maps recommendations to availability days
    - **Property 10: Workout scheduler maps recommendations to availability days**
    - **Validates: Requirements 9.1, 9.2**
    - File: `test/properties/workout_scheduler_properties_test.dart`
    - For any availability_days + recommendation, produces exactly one `ScheduledWorkout` per day

- [ ] 12. Integration — Wire caching repositories into providers, pull-to-refresh, end-to-end
  - [x] 12.1 Replace remote repository providers with caching providers
    - Update `lib/data/remote/providers.dart` to expose caching repositories instead of remote-only ones
    - Create `lib/data/caching/caching_providers.dart` binding `CachingExerciseRepository`, `CachingWorkoutRepository`, `CachingProfileRepository`, `CachingProgressRepository`
    - Update `exerciseRepositoryProvider`, `profileRepositoryProvider`, etc. to use caching versions
    - Initialize `LocalDatabase` and `SyncEngine` in app startup (`main.dart`)
    - _Requirements: 2.5, 11.1, 11.2_

  - [~] 12.2 Add pull-to-refresh support
    - Add `RefreshIndicator` to exercise library tab, recommendations tab, and progress screens
    - On refresh: force backend fetch regardless of cache age via `refreshCaches()` with `forceRefresh: true`
    - _Requirements: 11.3, 11.4_

  - [~] 12.3 Write integration tests for offline→online sync cycle
    - Test full offline mutation → reconnection → sync → cache refresh flow
    - Test profile edit while offline then sync with conflict
    - Test tab navigation with cached data, scroll/filter preservation
    - _Requirements: 4.1, 4.2, 4.5, 5.2, 5.3, 8.4_

- [~] 13. Final Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document using `glados` (already in dev_dependencies)
- The CachingRepository decorator pattern allows swapping remote-only → caching by changing provider bindings only
- Existing remote repositories remain unchanged; caching versions wrap them
- The `updatedAt` field addition to `UserProfile` is non-breaking (nullable)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "2.1"] },
    { "id": 2, "tasks": ["1.3", "2.2"] },
    { "id": 3, "tasks": ["3.1", "3.2", "3.3", "3.4", "5.1", "5.2"] },
    { "id": 4, "tasks": ["5.3", "6.1", "8.1"] },
    { "id": 5, "tasks": ["5.4", "6.2", "7.1", "8.2"] },
    { "id": 6, "tasks": ["6.3", "7.2", "7.3", "9.1", "9.2"] },
    { "id": 7, "tasks": ["7.4", "9.3"] },
    { "id": 8, "tasks": ["12.1"] },
    { "id": 9, "tasks": ["12.2", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "11.10"] },
    { "id": 10, "tasks": ["12.3"] }
  ]
}
```
