# Design Document: Offline Support and UI Enhancements

## Overview

This design covers three interconnected capabilities for SyncroFit:

1. **Offline Support** — A caching layer with SQLite persistence, connectivity monitoring, mutation queuing, background sync on reconnection, and last-write-wins conflict resolution.
2. **Profile Customization** — A dedicated profile edit screen with PATCH semantics, client-side validation, and offline-aware mutations.
3. **Tabbed Exercise/Recommendations UI** — A `TabBar`/`TabBarView` replacing the current exercise list screen, separating the exercise library from a personalized weekly workout scheduler.

The design preserves the existing repository interfaces (`ExerciseRepository`, `WorkoutRepository`, `ProfileRepository`, `ProgressRepository`) and introduces a `CachingRepository` decorator pattern that transparently adds offline persistence and sync-queue integration without modifying existing remote implementations.

## Architecture

```mermaid
graph TB
    subgraph UI Layer
        ES[Exercise Library Tab]
        RT[Recommendations Tab]
        WS[Workout Scheduler Widget]
        PE[Profile Edit Screen]
        OI[Offline Indicator Widget]
    end

    subgraph Provider Layer
        EP[ExerciseNotifier]
        WP[WorkoutNotifier]
        PP[ProfileNotifier]
        CP[ConnectivityNotifier]
        SP[SyncStatusNotifier]
    end

    subgraph Caching Layer
        CER[CachingExerciseRepository]
        CWR[CachingWorkoutRepository]
        CPR[CachingProfileRepository]
        CPRR[CachingProgressRepository]
    end

    subgraph Sync Engine
        SE[SyncEngine]
        SQ[SyncQueue]
        CR[ConflictResolver]
    end

    subgraph Local Storage
        DB[(SQLite Database)]
    end

    subgraph Network
        CM[ConnectivityMonitor]
        RER[RemoteExerciseRepository]
        RWR[RemoteWorkoutRepository]
        RPR[RemoteProfileRepository]
        RPRR[RemoteProgressRepository]
    end

    UI Layer --> Provider Layer
    Provider Layer --> Caching Layer
    Caching Layer --> DB
    Caching Layer --> Network
    SE --> SQ
    SE --> CR
    SE --> Caching Layer
    CM --> SE
    CM --> CP
```

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| CachingRepository decorator pattern | Keeps existing remote repositories unchanged; swapping to offline-aware versions requires only changing the Riverpod provider binding |
| SQLite via `sqflite` + `sqflite_common_ffi_web` | Cross-platform (Android, iOS, Web); structured queries for sync queue; well-supported in Flutter ecosystem |
| `connectivity_plus` for network detection | De-facto standard for Flutter connectivity monitoring; supports Android, iOS, Web, macOS |
| Last-write-wins conflict resolution | Simple, predictable, works well for single-user data; avoids merge complexity for a fitness app where the latest intent is almost always the correct state |
| SyncQueue persisted to SQLite | Survives app restarts; enables ordered replay; supports retry with exponential backoff |
| Tabbed UI via `DefaultTabController` | Native Material Design pattern; lightweight; integrates well with GoRouter for deep-link state preservation |

## Components and Interfaces

### ConnectivityMonitor

Wraps `connectivity_plus` and performs actual server reachability checks.

```dart
abstract class ConnectivityMonitor {
  /// Stream of connectivity state changes.
  Stream<ConnectivityStatus> get statusStream;

  /// Current connectivity status (synchronous snapshot).
  ConnectivityStatus get currentStatus;

  /// Perform a reachability check against the backend.
  Future<bool> checkServerReachability();

  void dispose();
}

enum ConnectivityStatus { online, offline }
```

**Implementation:** `ConnectivityMonitorImpl` listens to `Connectivity().onConnectivityChanged`, then validates actual reachability by pinging a lightweight backend health endpoint (`GET /api/health`). Status transitions are debounced 2 seconds to avoid flapping.

### SyncQueue

Persists pending mutations in SQLite.

```dart
class SyncMutation {
  final String id;
  final String entityType; // 'exercise', 'workout', 'profile', 'progress'
  final String entityId;
  final String operationType; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final SyncStatus status; // pending, inProgress, failed

  SyncMutation({...});
}

abstract class SyncQueue {
  Future<void> enqueue(SyncMutation mutation);
  Future<List<SyncMutation>> getPending();
  Future<void> markCompleted(String mutationId);
  Future<void> markFailed(String mutationId);
  Future<void> incrementRetry(String mutationId);
  Future<int> pendingCount();
  Future<void> clear();
}
```

### ConflictResolver

Implements last-write-wins using timestamps.

```dart
class ConflictResolver {
  /// Returns true if the local mutation should be applied.
  /// Returns false if the server version wins (conflict → local discarded).
  bool shouldApplyLocal({
    required DateTime localMutationTimestamp,
    required DateTime serverUpdatedAt,
  }) {
    return localMutationTimestamp.isAfter(serverUpdatedAt);
  }
}
```

### SyncEngine

Orchestrates sync on reconnection.

```dart
abstract class SyncEngine {
  /// Start listening for connectivity changes and auto-sync.
  void initialize();

  /// Process all pending mutations. Called on reconnection.
  Future<SyncResult> processQueue();

  /// Refresh all caches from backend after sync completes.
  Future<void> refreshCaches();

  /// Stream of sync events for UI indicators.
  Stream<SyncEvent> get syncEvents;

  void dispose();
}

enum SyncEvent { started, completed, conflictDetected, mutationFailed }

class SyncResult {
  final int successful;
  final int failed;
  final int conflicts;
  final List<String> failedMutationIds;
}
```

**Retry policy:** Transient failures (5xx, timeout) retry with exponential backoff: 2s, 4s, 8s (max 3 attempts). Validation errors (422) are marked as permanently failed.

### CachingRepository Pattern

Each caching repository wraps a remote repository and a local database DAO:

```dart
class CachingExerciseRepository implements ExerciseRepository {
  final RemoteExerciseRepository _remote;
  final ExerciseDao _dao;
  final SyncQueue _syncQueue;
  final ConnectivityMonitor _connectivity;

  @override
  Future<Result<List<Exercise>, AppError>> getAll() async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      final result = await _remote.getAll();
      if (result is Success) {
        await _dao.upsertAll(result.value);
        await _dao.updateLastSynced(DateTime.now());
      }
      return result;
    }
    // Offline: serve from cache
    final cached = await _dao.getAll();
    return Success(cached);
  }
  // ... other methods follow similar pattern
}
```

The same pattern applies to `CachingWorkoutRepository`, `CachingProfileRepository`, and `CachingProgressRepository`.

### LocalDatabase

Single SQLite database with tables for each entity type plus the sync queue:

```dart
abstract class LocalDatabase {
  Future<void> initialize();
  ExerciseDao get exerciseDao;
  WorkoutDao get workoutDao;
  ProfileDao get profileDao;
  ProgressDao get progressDao;
  SyncQueueDao get syncQueueDao;
  CacheMetadataDao get cacheMetadataDao;
  Future<void> close();
}
```

### Profile Edit Screen Components

```dart
/// Controller for the profile edit form.
class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  // Validates fields client-side before submission.
  // On save: if online → PATCH to backend; if offline → cache + enqueue.
}

class ProfileEditState {
  final Map<String, dynamic> dirtyFields; // Only changed fields
  final Map<String, String?> fieldErrors;
  final bool isSaving;
  final bool isSuccess;
}
```

### Tabbed Exercise/Recommendations Screen

```dart
/// Replaces ExerciseListScreen with a tabbed layout.
class ExerciseAndRecommendationsScreen extends ConsumerStatefulWidget {
  // Uses DefaultTabController with 2 tabs:
  // - Tab 0: ExerciseLibraryTab (existing filter/search UI refactored)
  // - Tab 1: RecommendationsTab (workout scheduler + daily plan)
}
```

### WorkoutScheduler Widget

```dart
class WorkoutSchedulerWidget extends ConsumerWidget {
  // Displays Mon-Sun row/grid
  // Maps recommendations to availability_days
  // Visual distinction: past (completed), today (active), future (upcoming)
}
```

## Data Models

### New Models

```dart
/// Represents a mutation queued for sync.
class SyncMutation {
  final String id;
  final String entityType;
  final String entityId;
  final String operationType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final SyncStatus status;

  const SyncMutation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() => { ... };
  factory SyncMutation.fromJson(Map<String, dynamic> json) => ...;
}

enum SyncStatus { pending, inProgress, failed }

/// Cache metadata tracking last sync time per entity type.
class CacheMetadata {
  final String entityType;
  final DateTime lastSyncedAt;

  const CacheMetadata({
    required this.entityType,
    required this.lastSyncedAt,
  });
}

/// A scheduled workout for a specific day of the week.
class ScheduledWorkout {
  final String workoutId;
  final String workoutName;
  final DayOfWeek dayOfWeek;
  final int estimatedDurationMinutes;
  final bool isCompleted;
  final DateTime? completedAt;

  const ScheduledWorkout({
    required this.workoutId,
    required this.workoutName,
    required this.dayOfWeek,
    required this.estimatedDurationMinutes,
    this.isCompleted = false,
    this.completedAt,
  });
}
```

### SQLite Schema

```sql
CREATE TABLE exercises (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  muscle_group TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  instructions TEXT NOT NULL, -- JSON array
  equipment TEXT,
  default_duration_seconds INTEGER NOT NULL,
  default_sets INTEGER NOT NULL,
  default_reps INTEGER NOT NULL,
  image_url TEXT
);

CREATE TABLE workouts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  estimated_duration_minutes INTEGER NOT NULL,
  day_of_week TEXT, -- nullable, for scheduled workouts
  exercises TEXT NOT NULL -- JSON array of WorkoutExercise
);

CREATE TABLE workout_sessions (
  id TEXT PRIMARY KEY,
  workout_id TEXT NOT NULL,
  workout_name TEXT NOT NULL,
  completed_at TEXT NOT NULL,
  total_duration_seconds INTEGER NOT NULL,
  exercises_completed INTEGER NOT NULL,
  exercises TEXT NOT NULL -- JSON array of CompletedExercise
);

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
  availability_days TEXT NOT NULL, -- JSON array
  updated_at TEXT NOT NULL
);

CREATE TABLE progress_records (
  id TEXT PRIMARY KEY,
  recorded_at TEXT NOT NULL,
  weight_kg REAL NOT NULL,
  bmi REAL NOT NULL,
  workouts_completed INTEGER NOT NULL
);

CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  payload TEXT NOT NULL, -- JSON
  created_at TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE cache_metadata (
  entity_type TEXT PRIMARY KEY,
  last_synced_at TEXT NOT NULL
);
```

### Existing Model Changes

The existing models (`Exercise`, `Workout`, `UserProfile`, `ProgressRecord`, `WorkoutSession`, `WorkoutExercise`) already have `toJson()` and `fromJson()` methods, so they can be serialized to/from SQLite without modification. The `UserProfile` model will gain an optional `updatedAt` field for conflict resolution:

```dart
// Addition to UserProfile (non-breaking)
class UserProfile {
  // ... existing fields ...
  final DateTime? updatedAt; // Added for conflict resolution
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Sync queue preserves chronological order

*For any* sequence of offline mutations performed by the user, the SyncQueue SHALL maintain and return them in the exact chronological order they were enqueued, regardless of entity type or operation type.

**Validates: Requirements 3.3**

### Property 2: Offline mutations are reflected in local cache immediately

*For any* write operation performed while offline, reading the same entity from the local cache immediately after the mutation SHALL return the mutated value.

**Validates: Requirements 3.4**

### Property 3: Sync queue round-trip persistence

*For any* valid SyncMutation, enqueueing it to the SyncQueue and then retrieving pending mutations SHALL yield a list containing a mutation equivalent to the original (serialization round-trip preserves all fields).

**Validates: Requirements 3.2**

### Property 4: Conflict resolution is deterministic — last-write-wins

*For any* pair of timestamps (localMutationTimestamp, serverUpdatedAt), the ConflictResolver SHALL return `true` (apply local) if and only if localMutationTimestamp is strictly after serverUpdatedAt; otherwise it SHALL return `false` (server wins).

**Validates: Requirements 5.1, 5.2**

### Property 5: Successful sync removes mutation from queue

*For any* mutation that is successfully synced (server returns 2xx), the SyncQueue SHALL no longer contain that mutation after processing completes.

**Validates: Requirements 4.2**

### Property 6: Profile validation rejects out-of-range values

*For any* age value outside [13, 120], or height_cm outside [50, 300], or weight_kg outside [20, 500], the profile validation SHALL reject the input and return a field-specific error.

**Validates: Requirements 6.5**

### Property 7: Profile PATCH sends only changed fields

*For any* profile edit where a subset of fields are modified, the resulting PATCH payload SHALL contain exactly and only the modified fields (dirty fields), not the full profile object.

**Validates: Requirements 6.2**

### Property 8: Cache freshness — stale data triggers refresh

*For any* cache entry whose `lastSyncedAt` is older than 15 minutes and the device is online, the CachingRepository SHALL fetch fresh data from the backend rather than serving the stale cache.

**Validates: Requirements 11.1, 11.2**

### Property 9: Exercise filtering preserves existing behavior

*For any* combination of muscle group filters, difficulty filter, and search query applied to an exercise list, the filtered results SHALL be a subset of all exercises where each result matches ALL active filter criteria (AND logic across filter types, OR logic within muscle groups).

**Validates: Requirements 8.5**

### Property 10: Workout scheduler maps recommendations to availability days

*For any* user with defined availability_days and a generated recommendation, the WorkoutScheduler SHALL produce exactly one ScheduledWorkout per availability day, with each workout mapped to its corresponding day_of_week field.

**Validates: Requirements 9.1, 9.2**

## Error Handling

### Network Errors (Offline Transitions)

| Scenario | Handling |
|----------|----------|
| Network request fails while online | ConnectivityMonitor re-checks reachability; if server unreachable, transitions to offline mode |
| Mutation attempted while offline | Applied to local cache immediately; enqueued to SyncQueue; no error shown to user |
| Sync fails with 5xx / timeout | Retry with exponential backoff (2s, 4s, 8s); max 3 attempts; mark as failed after exhaustion |
| Sync fails with 422 | Mark mutation as permanently failed; notify user with field-specific error details |

### Conflict Handling

| Scenario | Handling |
|----------|----------|
| Server record newer than local mutation | Discard local mutation; notify user via snackbar that their offline change was overridden |
| Local mutation newer than server record | Apply local mutation to server (normal sync) |

### Profile Validation Errors

| Field | Validation | Error Message |
|-------|-----------|---------------|
| age | 13–120 | "Age must be between 13 and 120" |
| height_cm | 50–300 | "Height must be between 50 and 300 cm" |
| weight_kg | 20–500 | "Weight must be between 20 and 500 kg" |
| name | Non-empty | "Name is required" |

### Database Errors

| Scenario | Handling |
|----------|----------|
| SQLite initialization fails | Fall back to remote-only mode; log error; display warning |
| SQLite write fails | Retry once; if still fails, show error toast; continue without cache |
| Database corruption detected | Delete and recreate database; force full refresh from backend |

### UI Error States

- Profile edit: Field-specific error messages displayed inline below each input
- Sync failures: Bottom notification bar with description of affected data
- Exercise loading: Retry button with error message
- Tab preservation: If data fails to load in one tab, the other tab remains functional

## Testing Strategy

### Property-Based Testing

The project already uses `glados` (a Dart PBT library) as a dev dependency. Each correctness property will be implemented as a property-based test with minimum 100 iterations.

**Library:** `glados` ^1.1.7 (already in pubspec.yaml)

**Test structure:**
- `test/properties/sync_queue_properties_test.dart` — Properties 1, 2, 3, 5
- `test/properties/conflict_resolver_properties_test.dart` — Property 4
- `test/properties/profile_validation_properties_test.dart` — Properties 6, 7
- `test/properties/cache_freshness_properties_test.dart` — Property 8
- `test/properties/exercise_filter_properties_test.dart` — Property 9
- `test/properties/workout_scheduler_properties_test.dart` — Property 10

Each property test will be tagged with a comment:
```dart
// Feature: offline-support-and-ui-enhancements, Property 1: Sync queue preserves chronological order
```

**Minimum configuration:** 100 iterations per property via Glados `explore` count.

### Unit Tests (Example-Based)

| Area | Test Focus |
|------|-----------|
| ConnectivityMonitor | Specific transitions: online→offline, offline→online; debounce behavior |
| SyncEngine.processQueue | Empty queue, single mutation, multiple mutations, mixed success/failure |
| CachingRepository | Online path (fresh cache), online path (stale cache), offline path |
| ProfileEditNotifier | Submit with valid data, submit with invalid data, partial field changes |
| WorkoutSchedulerWidget | No recommendations state, complete week, partial availability |
| Offline Indicator | Shows when offline, hides when online, shows pending count |

### Integration Tests

| Scenario | What It Validates |
|----------|-------------------|
| Full offline→online cycle | Mutations queue correctly, sync processes in order, cache refreshes |
| Profile edit while offline then sync | PATCH payload correctness, conflict handling on reconnect |
| Tab navigation with cached data | Tab state preserved, scroll position maintained, filters persist |
| Pull-to-refresh while online | Forces backend fetch regardless of cache age |

### Widget Tests

| Widget | Test Focus |
|--------|-----------|
| ExerciseAndRecommendationsScreen | Tab switching, state preservation |
| WorkoutSchedulerWidget | Day rendering, tap navigation, empty state prompt |
| ProfileEditScreen | Form validation, loading states, success navigation |
| OfflineIndicatorWidget | Visibility based on connectivity state |
| SyncPendingBadge | Count display, disappearance on sync complete |
