# SyncroFit Entity Relationship Diagram

This document describes the SyncroFit relational schema after the 3NF
normalization (migration `2026_10_26_000001_normalize_schema_to_3nf`). It is
generated from the live migrated schema, so every table, column, and foreign
key below is traceable to an actual database constraint.

Framework-internal tables (`migrations`, `cache`, `cache_locks`, `jobs`,
`job_batches`, `failed_jobs`, `password_reset_tokens`, `sessions`,
`personal_access_tokens`) are intentionally omitted — they are not part of the
domain model.

## Diagram

```mermaid
erDiagram
    users ||--o| profiles : "has one"
    users ||--o{ workouts : "owns"
    users ||--o{ workout_history : "logs"
    users ||--o{ progress_logs : "records"
    users ||--o{ posts : "authors"
    users ||--o{ comments : "writes"
    users ||--o{ post_likes : "gives"

    profiles ||--o{ profile_availability : "available on"

    workouts ||--o{ workout_exercises : "contains"
    exercises ||--o{ workout_exercises : "prescribed in"

    workout_history ||--o{ workout_history_exercises : "contains"
    exercises |o--o{ workout_history_exercises : "snapshot of"

    posts ||--o{ comments : "has"
    posts ||--o{ post_likes : "receives"
    posts ||--o{ post_media : "has"

    users {
        int id PK
        varchar email UK
        varchar username UK
        varchar password
        text first_name
        text last_name
        varchar avatar_disk
        varchar avatar_path
        varchar avatar_mime_type
        datetime created_at
        datetime updated_at
    }

    profiles {
        int id PK
        int user_id FK
        int age
        numeric height_cm
        numeric weight_kg
        varchar gender
        varchar goal
        varchar fitness_level
        varchar workout_preference
        datetime created_at
        datetime updated_at
    }

    profile_availability {
        int id PK
        int profile_id FK
        varchar day_of_week
        datetime created_at
        datetime updated_at
    }

    exercises {
        int id PK
        varchar name
        text description
        text instructions
        varchar muscle_group
        varchar equipment
        varchar difficulty
        int default_sets
        int default_reps
        int default_duration_seconds
        varchar video_path
        varchar movement_pattern
        text primary_muscles
        text secondary_muscles
        varchar exercise_type
        text goals
        text environments
        varchar verification_status
        varchar source_reference
        datetime created_at
        datetime updated_at
    }

    workouts {
        int id PK
        int user_id FK
        varchar name
        varchar day_of_week
        int estimated_duration_minutes
        tinyint is_generated
        varchar plan_id
        tinyint is_accepted
        datetime accepted_at
        datetime created_at
        datetime updated_at
    }

    workout_exercises {
        int id PK
        int workout_id FK
        int exercise_id FK
        int sets
        int reps
        int duration_seconds
        int rest_seconds
        int position
        datetime created_at
        datetime updated_at
    }

    workout_history {
        int id PK
        int user_id FK
        varchar workout_name
        datetime completed_at
        int total_duration_seconds
        varchar client_mutation_id
        datetime created_at
        datetime updated_at
    }

    workout_history_exercises {
        int id PK
        int workout_history_id FK
        int exercise_id FK "nullable"
        varchar exercise_name
        int sets_completed
        int reps_or_duration
        tinyint is_duration
        int position
        datetime created_at
        datetime updated_at
    }

    progress_logs {
        int id PK
        int user_id FK
        varchar title
        text description
        numeric weight_kg
        varchar original_image_path
        varchar display_image_path
        datetime created_at
        datetime updated_at
    }

    posts {
        int id PK
        int user_id FK
        text content
        datetime created_at
        datetime updated_at
        datetime deleted_at
    }

    comments {
        int id PK
        int post_id FK
        int user_id FK
        text content
        datetime created_at
        datetime updated_at
        datetime deleted_at
    }

    post_likes {
        int id PK
        int post_id FK
        int user_id FK
        datetime created_at
        datetime updated_at
    }

    post_media {
        int id PK
        int post_id FK
        varchar disk
        varchar path
        varchar mime_type
        int size_bytes
        int width
        int height
        int position
        datetime created_at
        datetime updated_at
    }
```

## Relationships

| Parent | Child | Cardinality | FK column | On delete |
| --- | --- | --- | --- | --- |
| users | profiles | 1 : 0..1 | profiles.user_id | CASCADE |
| users | workouts | 1 : 0..N | workouts.user_id | CASCADE |
| users | workout_history | 1 : 0..N | workout_history.user_id | CASCADE |
| users | progress_logs | 1 : 0..N | progress_logs.user_id | CASCADE |
| users | posts | 1 : 0..N | posts.user_id | CASCADE |
| users | comments | 1 : 0..N | comments.user_id | CASCADE |
| users | post_likes | 1 : 0..N | post_likes.user_id | CASCADE |
| profiles | profile_availability | 1 : 0..N | profile_availability.profile_id | CASCADE |
| workouts | workout_exercises | 1 : 0..N | workout_exercises.workout_id | CASCADE |
| exercises | workout_exercises | 1 : 0..N | workout_exercises.exercise_id | CASCADE |
| workout_history | workout_history_exercises | 1 : 0..N | workout_history_exercises.workout_history_id | CASCADE |
| exercises | workout_history_exercises | 1 : 0..N (optional) | workout_history_exercises.exercise_id | SET NULL |
| posts | comments | 1 : 0..N | comments.post_id | CASCADE |
| posts | post_likes | 1 : 0..N | post_likes.post_id | CASCADE |
| posts | post_media | 1 : 0..N | post_media.post_id | CASCADE |

## Unique constraints

- `users` — `email`, `username`
- `profile_availability` — (`profile_id`, `day_of_week`)
- `workout_exercises` — (`workout_id`, `position`)
- `workout_history` — (`user_id`, `client_mutation_id`) — enforces idempotent
  offline sync of completed sessions
- `post_likes` — (`post_id`, `user_id`) — one like per user per post
- `post_media` — (`post_id`, `position`)

## Normalization notes (3NF)

The `2026_10_26_000001_normalize_schema_to_3nf` migration eliminated repeating
groups and derived/transitive columns that previously violated normal form:

1. **`profile_availability`** replaces the former JSON `profiles.availability_days`
   column. Each available weekday is now its own row with a real FK to
   `profiles`, removing a multi-valued attribute (1NF/2NF) and making
   availability queryable and referentially traceable.

2. **`workout_exercises`** replaces the former JSON `workouts.exercises` column.
   Each prescribed exercise is a row with a non-null FK to `exercises`
   (`onDelete=CASCADE`) plus the per-exercise prescription (`sets`, `reps`,
   `duration_seconds`, `rest_seconds`, `position`). `position` is unique per
   workout to preserve ordering.

3. **`workout_history_exercises`** replaces the former JSON
   `workout_history.exercises_completed` column. It keeps a **nullable** FK to
   `exercises` (`onDelete=SET NULL`) alongside a denormalized `exercise_name`
   snapshot. The snapshot is deliberate: historical records must remain
   human-readable even if the catalog exercise is later removed — deleting an
   exercise nulls the FK but preserves the recorded `exercise_name`, sets, and
   reps/duration. This is intentional historical-fact retention, not a 3NF
   violation.

4. **`profiles.bmi`** was dropped. BMI is a transitive dependency
   (derivable from `height_cm` and `weight_kg`), so it is now a computed
   accessor on the `Profile` model rather than a stored column.

### API contract preservation

Although storage is normalized, the external JSON/API contract is unchanged.
Eloquent models re-expose the former shapes as virtual attributes backed by the
new relations:

- `Profile.availability_days` ← `profile_availability`
- `Profile.bmi` ← computed from `height_cm` / `weight_kg`
- `Workout.exercises` ← `workout_exercises`
- `WorkoutHistory.exercises_completed` ← `workout_history_exercises`

The Flutter client, offline SQLite cache, and serialization therefore require no
changes.

---

_Generated from the migrated schema on 2026-10-26. To regenerate, run all
migrations against a scratch database and introspect the resulting tables,
columns, and foreign keys._
