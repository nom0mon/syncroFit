# SyncroFit

SyncroFit is an **Android-only** fitness application built with Flutter and a Laravel REST API backend. Android is the only supported client runtime and release target. The supported product covers Android 7.0 (API 24) through Android 15 (API 35) on phones, tablets, and single-window foldable layouts from 320–1,280 dp.

## Features

- **Authentication** — register, login, logout, and forgot-password flows using Laravel Sanctum token authentication.
- **User profile** — create, view, and edit fitness profile and workout-availability data.
- **Exercise library** — browse and filter exercises and view exercise instructions.
- **Workout recommendation engine** — generate schedule-aware workout plans from profile, goals, equipment, and exercise preferences.
- **Active workouts** — complete per-set workout flows with rest timing and session summaries.
- **Progress tracking** — review workout totals, weekly statistics, planned-versus-completed activity, and recent history.
- **Offline-first data** — cache data in SQLite and synchronize queued mutations when connectivity returns.
- **Settings** — manage appearance, local notification preferences, account security, and sign-out.

Some routed or placeholder features identified by the Android completion audit are still being implemented or retired before release. Do not treat mock-only, unreachable, or placeholder behavior as production-ready; see `PRD.md` section 5 and `.kiro/specs/android-completion/audit.md`.

## Technology

### Android client

- Flutter 3.44.0 / Dart 3.12.0 baseline
- Riverpod state management and `go_router` routing
- Dio networking
- SQLite (`sqflite`) caching and sync queue
- Android secure storage and shared preferences
- Flutter unit, widget, and Glados property tests

### Backend

- Laravel 12 and Sanctum
- MySQL 8 runtime database
- In-memory SQLite test database
- PHPUnit and Eris property tests

## Project structure

```text
syncroFit/
├── android/                      # The only supported Flutter platform target
├── lib/                          # Flutter application
│   ├── core/                     # Routing, networking, theme, models, utilities
│   ├── data/                     # Remote/local repositories, cache, and sync
│   ├── features/                 # Product feature modules
│   └── shared/                   # Shared widgets and models
├── test/                         # Flutter unit, widget, and property tests
├── backend/                      # Laravel API, migrations, seeders, and tests
├── docs/
│   ├── android-development.md    # Contributor onboarding and local device setup
│   ├── android-qa-release.md     # Android QA matrix and release procedure
│   └── android-responsive-layout.md
└── assets/
```

## Developer onboarding

### Required tools

- Flutter 3.44.0 stable with Dart 3.12.0 (the captured clean-checkout baseline)
- Android Studio and Android SDK command-line tools
- Android SDK Platform 35 or newer, with an API 24 and an API 35 emulator image available for minimum/latest coverage
- JDK 17
- PHP 8.4.1 or newer for the current `composer.lock`, Composer 2.x, and MySQL 8.0+

Validate the Android toolchain before restoring dependencies:

```powershell
flutter --version
flutter doctor -v
flutter doctor --android-licenses
```

`flutter doctor -v` must report a healthy Android toolchain. Other Flutter host toolchains are outside this repository's support scope.

### Restore and run

```powershell
flutter pub get --enforce-lockfile
Set-Location backend
composer install --no-interaction --prefer-dist --no-progress
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8000
```

In a second terminal, connect an Android emulator or a USB-debuggable physical Android device, then run:

```powershell
adb reverse tcp:8000 tcp:8000
flutter devices
flutter run -d <android-device-id>
```

The app currently uses `http://127.0.0.1:8000` from `lib/core/network/api_config.dart`; `adb reverse` maps that device endpoint to the local Laravel server. Use an approved HTTPS development endpoint instead when reverse port forwarding is unavailable. Do not enable cleartext traffic in release configuration.

Complete emulator, physical-device, networking, NDK, and troubleshooting instructions are in [`docs/android-development.md`](docs/android-development.md).

## Supported commands

These are the supported client validation and build commands:

```powershell
flutter analyze
flutter test --reporter compact
flutter build apk --debug
flutter build appbundle --release
```

- The debug APK is for local Android QA only.
- The Android App Bundle is the only release artifact. A release candidate must be named `synchrofit-android-<MAJOR.MINOR.PATCH>-<BUILD>-release.aab` from the `pubspec.yaml` version.
- A production AAB requires protected release signing; the current clean-checkout baseline still uses debug signing and is not releasable.
- Do not use generated artifacts from a build command that exits nonzero.

Run backend validation from `backend/`:

```powershell
php artisan test
```

See [`docs/android-qa-release.md`](docs/android-qa-release.md) for the mandatory device matrix, full release gates, signing constraints, artifact handling, and current blockers.

## API endpoints

Protected routes require a Sanctum bearer token (`auth:sanctum`). Current core routes include:

- `POST /api/register`, `POST /api/login`, `POST /api/forgot-password`
- `POST /api/logout`
- `GET|POST|PUT /api/profile`
- `GET /api/exercises`, `GET /api/exercises/{exercise}`
- `GET /api/workouts`, `POST /api/workouts`, `POST /api/workouts/generate`
- `GET /api/workouts/generated`
- `POST /api/workout-history`, `GET /api/workout-history`, `GET /api/workout-history/stats`

The Android completion plan adds or retires other routes before production release; the code and API tests are authoritative during that work.