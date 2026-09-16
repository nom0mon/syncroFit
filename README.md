Download the _installer_ here:
> SyncroFit v1.1 - **https://drive.google.com/file/d/1lrJBO8gl8hLuClwEKhNddalqdza6stGR/view?usp=sharing**

# SyncroFit

SyncroFit is an Android fitness application built with Flutter and a Laravel REST API. It supports Android 7.0 (API 24) through Android 15 (API 35), responsive phone/tablet layouts, authenticated cloud data, and offline access to cached user data.

## Features

- Authentication with unique usernames and Laravel Sanctum tokens.
- Fitness profiles with goals, level, measurements, preferences, and workout availability.
- Exercise library with filtering, instructions, sourced movement illustrations, and consistently formatted names.
- Standalone exercise sessions with user-selected sets, repetitions or timed sets, and rest periods.
- Profile-aware weekly workout generation for Home, Gym, or Outdoor training, with an explicit accept-plan step.
- Workout customization that lets users add, remove, and reorder exercises while the server derives safe sets, repetitions, duration, and rest periods.
- Active per-set workouts, rest timers, completion summaries, and workout-history synchronization.
- Dashboard schedule calendar, availability-aware weekly progress, goal progress, streak, and weekly load.
- Progress module with profile-derived BMI, workout history with exercise details, and private photo progress logs grouped by month.
- Community feed with text/photo posts, likes, and comments. Reposts and sharing are intentionally excluded.
- Account-scoped SQLite caching, retained offline sessions, and queued synchronization where supported.
- Offline-capable Android reminders for accepted workout days, managed through Android system settings.

## Recommendation approach

SyncroFit does not use a generative AI model to create workout plans. Its recommendation engine is deterministic and rule-based. It selects exercises using the member's fitness goal, fitness level, available workout days, training environment, exercise difficulty, equipment requirements, and movement-pattern balance.

- **Home** plans use equipment-free movements appropriate for limited indoor space.
- **Gym** plans may use bodyweight, dumbbells, kettlebells, resistance bands, barbells, and machines.
- **Outdoor** plans use equipment-free movements and emphasize open-space conditioning such as walking, running-in-place, and jumping movements.

Sets, repetitions, timed durations, and rest periods are assigned by the server's prescription policy. Users may add, remove, and reorder exercises in recommended plans, but the safety-related prescription remains server-controlled. Standalone library sessions are intentionally user-configurable.

Exercise identity and taxonomy are cross-checked against [Free Exercise DB](https://github.com/yuhonas/free-exercise-db). Programming principles are documented in [Resistance Training Prescription Policy](docs/resistance-training-prescription-policy.md), and third-party asset notices are provided in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Catalog validation does not guarantee individual safety or outcomes.

The implementation status and feature decisions are tracked in [CODEX_SPEC.md](CODEX_SPEC.md). The development timeline, sprint outcomes, defect feedback, and release-readiness assessment are documented in the [Agile Sprint Progress Report](docs/agile-sprint-progress-report.md).

## Technology

### Android client

- Flutter 3.44.0 and Dart 3.12.0 baseline
- Riverpod and `go_router`
- Dio networking
- SQLite (`sqflite`) cache and synchronization queue
- Secure token storage and shared preferences
- Android local notifications
- Flutter unit, widget, and Glados property tests

### Backend and hosting

- Laravel 12 with Sanctum
- PostgreSQL production database and isolated SQLite tests
- Render API: `https://syncrofit-api.onrender.com`
- Private Supabase S3-compatible storage for Community and progress photos
- PHPUnit and Eris tests

The production health endpoint is `https://syncrofit-api.onrender.com/api/health`.

## Project structure

```text
syncroFit/
|-- .github/workflows/       # Continuous integration and release jobs
|-- android/                 # Android runner and release configuration
|-- assets/                  # Application icon and exercise artwork
|-- backend/                 # Laravel API, migrations, seeders, and tests
|-- docs/                    # Development, responsive-layout, and QA guides
|-- lib/
|   |-- core/                # Routing, networking, notifications, and theme
|   |-- data/                # Remote/local repositories, cache, and sync
|   |-- features/            # Product feature modules
|   `-- shared/              # Shared models and widgets
|-- test/                    # Flutter tests
|-- CODEX_SPEC.md            # Feature contract and progress tracker
|-- THIRD_PARTY_NOTICES.md   # Dataset and artwork licensing notices
`-- pubspec.yaml
```

Generated builds, APK installers, local databases, uploaded development media, compiled Laravel views, dependency folders, logs, IDE settings, and signing credentials are intentionally excluded from version control.

## Requirements

- Flutter 3.44.0 stable with Dart 3.12.0
- Android Studio, Android SDK command-line tools, and Platform 35 or newer
- JDK 17
- ADB for physical-device installation
- PHP 8.4.1 or newer, Composer 2, and PostgreSQL or MySQL for local backend development

Validate the Android toolchain:

```powershell
flutter --version
flutter doctor -v
flutter doctor --android-licenses
```

## Run against the deployed backend

The checked-in production fallback is the Render API, but the explicit definition below makes the selected backend unambiguous:

```powershell
Set-Location C:\repos\synchrofit\syncroFit
flutter pub get
flutter devices
flutter run -d <android-device-id> --dart-define=API_BASE_URL=https://syncrofit-api.onrender.com
```

## Run against local Laravel

Prepare and start Laravel:

```powershell
Set-Location C:\repos\synchrofit\syncroFit\backend
composer install --no-interaction --prefer-dist --no-progress
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8000
```

Keep Laravel running. In a second terminal:

```powershell
Set-Location C:\repos\synchrofit\syncroFit
adb reverse tcp:8000 tcp:8000
flutter devices
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

`adb reverse` maps the phone's loopback port to the computer. It may need to be repeated after reconnecting the device. Do not build a tester release against localhost.

See [docs/android-development.md](docs/android-development.md) for emulator, physical-device, networking, and troubleshooting details.

## Validation

```powershell
flutter analyze
flutter test --reporter compact
Set-Location backend
php artisan test
```

Do not distribute an artifact produced by a command that exits unsuccessfully.

## API overview

Protected routes require a Sanctum bearer token. Major routes include:

- `GET /api/health`
- Authentication: register, login, logout, forgot password, and password change
- Profile: `GET|POST|PUT /api/profile`
- Exercise library: `GET /api/exercises` and `GET /api/exercises/{exercise}`
- Workouts: list, create, generate using profile/environment rules, accept plan, and customize exercises
- Workout history: create, list, and statistics
- Private progress logs: list, create, show, retrieve image, and delete
- Community: posts, photos, likes, comments, and owner-authorized deletion

The definitions in [backend/routes/api.php](backend/routes/api.php) and the API tests are authoritative.
