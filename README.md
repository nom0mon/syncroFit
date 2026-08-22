# SyncroFit

SyncroFit is a fitness application with a **Flutter** mobile/web client and a **Laravel** REST API backend. It generates personalized, schedule-aware workout plans, tracks completed sessions, and works offline-first with local caching and background sync.

## Features

- **Authentication** — register, login, logout, and forgot-password flows (Laravel Sanctum token auth).
- **User Profile** — set up and edit your profile (age, height, weight, gender, fitness goal, level, workout preference, and available training days). Read-only profile view with an edit action.
- **Exercise Library** — browse exercises with search and filtering by muscle group and difficulty, plus an exercise detail screen with a procedure guide and video placeholder.
- **Workout Recommendation Engine** — a rule-based, movement-pattern-driven generator that builds a weekly plan from your selected available days:
  - Determines the split by day count (1 day → Full Body; 2–3 → Full Body A/B/C; 4 → Upper/Lower; 5 → Upper/Lower/Full Body; 6+ → Push/Pull/Legs, reserving a recovery day on 7).
  - Fills movement-pattern slots (knee/hip dominant, horizontal/vertical push/pull, core, accessory) and scores candidates by goal, equipment, difficulty, variety, and include/exclude preferences.
  - Validates weekly muscle coverage and maps each workout to your exact selected day.
  - Generation is **explicit** — workouts are only created when you press **Generate Workout**.
- **Active Workout (per-set flow)** — performs one set at a time ("Set 1 · 8 reps") with a Finish Set button; a rest timer applies after the last set of each exercise. Shows the exercise procedure and a video guide area.
- **Progress Tracking** — total workouts, total duration, weekly statistics, a "This Week" planned-vs-completed indicator, and recent workout history.
- **Dashboard** — today's workout, weekly training load chart, and a weekly schedule overview.
- **Offline-first** — local SQLite caching, a sync queue for offline mutations, and automatic sync when connectivity resumes.
- **Settings** — dark mode toggle, notification settings, change password, and sign out.

## Tech Stack

### Frontend (Flutter)
- **State management:** flutter_riverpod
- **Routing:** go_router
- **Networking:** dio
- **Local storage:** sqflite / sqflite_common_ffi_web, flutter_secure_storage, shared_preferences
- **Charts:** fl_chart
- **Connectivity:** connectivity_plus
- **Testing:** flutter_test, mocktail, glados (property-based testing)

### Backend (Laravel)
- **Framework:** Laravel (PHP)
- **Auth:** Laravel Sanctum
- **Database:** MySQL / SQLite
- **Testing:** PHPUnit with Eris (property-based testing)

## Project Structure

```
syncroFit/
├── lib/                          # Flutter app
│   ├── core/                     # Router, network, theme, models, utils
│   ├── data/                     # Repositories, remote/caching, local DB, sync
│   ├── features/                 # Feature modules
│   │   ├── auth/
│   │   ├── profile/
│   │   ├── exercise_library/
│   │   ├── workout/              # Generator, active session, rest timer
│   │   ├── dashboard/
│   │   ├── progress/
│   │   ├── settings/
│   │   ├── community/
│   │   ├── consultation/
│   │   └── ...
│   └── shared/                   # Shared models and widgets
├── test/                         # Unit, widget, integration, property tests
├── backend/                      # Laravel API
│   ├── app/Http/Controllers/     # Auth, Profile, Exercise, Workout, WorkoutHistory
│   ├── app/Models/               # User, Profile, Exercise, Workout, WorkoutHistory
│   ├── app/Services/             # RecommendationEngine
│   ├── database/migrations/
│   └── database/seeders/         # ExerciseSeeder
└── assets/
```

## Database Schema

The backend uses a simplified 5-table core schema:

- **users** — accounts (first_name, last_name, email, password).
- **profiles** — user fitness profile and availability days.
- **exercises** — exercise library with movement pattern, primary/secondary muscles, exercise type, equipment, difficulty, goals, and a video path.
- **workouts** — user-created and generated workouts; exercises are embedded as a JSON array with an `is_generated` flag.
- **workout_history** — completed session records used to derive progress statistics.

## API Endpoints

All protected routes require a Sanctum bearer token (`auth:sanctum`).

**Auth (public):**
- `POST /api/register`
- `POST /api/login`
- `POST /api/forgot-password`

**Protected:**
- `POST /api/logout`
- `GET|POST|PUT /api/profile`
- `GET /api/exercises`, `GET /api/exercises/{exercise}`
- `GET /api/workouts`, `POST /api/workouts`
- `POST /api/workouts/generate` — generate a weekly plan (accepts optional `included_exercises` / `excluded_exercises`)
- `GET /api/workouts/generated`
- `POST /api/workout-history`, `GET /api/workout-history`, `GET /api/workout-history/stats`

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.0.0)
- PHP (>= 8.1) and Composer
- MySQL (or SQLite)

### Backend Setup

```bash
cd backend
composer install
cp .env.example .env        # configure DB_DATABASE, DB_USERNAME, DB_PASSWORD
php artisan key:generate
php artisan migrate --seed  # creates the schema and seeds the exercise library
php artisan serve           # serves the API at http://localhost:8000
```

### Frontend Setup

```bash
flutter pub get
flutter run                 # or: flutter run -d chrome
```

Configure the API base URL in `lib/core/network/api_config.dart` to point at your backend.

## Testing

**Frontend:**
```bash
flutter test
```

**Backend:**
```bash
cd backend
php artisan test
```

Both suites include property-based tests (glados on the frontend, Eris on the backend) covering serialization round-trips, validation, DAO integrity, and statistics computation.
