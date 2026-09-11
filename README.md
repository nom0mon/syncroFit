Download the _installer_ here:
> SyncroFit v1.1 - **https://drive.google.com/file/d/1lrJBO8gl8hLuClwEKhNddalqdza6stGR/view?usp=sharing**

# SyncroFit

SyncroFit is an Android fitness application built with Flutter and a Laravel REST API. It supports Android 7.0 (API 24) through Android 15 (API 35), responsive phone/tablet layouts, authenticated cloud data, and offline access to cached user data.

## Features

- Authentication with unique usernames and Laravel Sanctum tokens.
- Fitness profiles with goals, level, measurements, preferences, and workout availability.
- Exercise library with filtering, instructions, and consistently formatted names.
- Profile-aware weekly workout generation with an explicit accept-plan step.
- Workout customization that lets users add, remove, and reorder exercises while the server derives safe sets, repetitions, duration, and rest periods.
- Active per-set workouts, rest timers, completion summaries, and workout-history synchronization.
- Dashboard schedule calendar, weekly progress, goal progress, streak, and weekly load.
- Progress module with profile-derived BMI, workout history with exercise details, and private photo progress logs grouped by month.
- Community feed with text/photo posts, likes, and comments. Reposts and sharing are intentionally excluded.
- Account-scoped SQLite caching, retained offline sessions, and queued synchronization where supported.
- Offline-capable Android reminders for accepted workout days, managed through Android system settings.

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
- MySQL-compatible production database and SQLite tests
- Render API: `https://syncrofit-api.onrender.com`
- Private S3-compatible media storage
- PHPUnit and Eris tests

The production health endpoint is `https://syncrofit-api.onrender.com/api/health`.

## Project structure

```text
syncroFit/
├── android/                 # Android runner and release configuration
├── backend/                 # Laravel API, migrations, seeders, and tests
├── docs/                    # Development, responsive-layout, and QA guides
├── lib/
│   ├── core/                # Routing, networking, notifications, and theme
│   ├── data/                # Remote/local repositories, cache, and sync
│   ├── features/            # Product feature modules
│   └── shared/              # Shared models and widgets
├── test/                    # Flutter tests
├── CODEX_SPEC.md            # Feature contract and progress tracker
└── pubspec.yaml
```

## Requirements

- Flutter 3.44.0 stable with Dart 3.12.0
- Android Studio, Android SDK command-line tools, and Platform 35 or newer
- JDK 17
- ADB for physical-device installation
- PHP 8.4.1 or newer, Composer 2, and MySQL 8 for local backend development

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

## Create the tester installer

The release APK is the direct-install Android installer:

```powershell
Set-Location C:\repos\synchrofit\syncroFit
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://syncrofit-api.onrender.com
Copy-Item .\build\app\outputs\flutter-apk\app-release.apk .\SyncroFit-Tester.apk
```

The finished installer is:

```text
C:\repos\synchrofit\syncroFit\SyncroFit-Tester.apk
```

Transfer it by USB or a trusted file-sharing service. On the tester's phone, open the APK and allow installation from the selected browser or file manager when Android requests it.

### Clean-install verification

1. Confirm pending offline changes have synchronized.
2. Uninstall existing development copies of SyncroFit.
3. Disconnect USB.
4. Transfer and install `SyncroFit-Tester.apk`.
5. Sign in and allow camera and notification permissions when needed.
6. Confirm the offline banner disappears after Render wakes.
7. Confirm the profile, accepted workouts, dashboard progress, Community photos, progress logs, camera/gallery, and test workout reminder.
8. Close and reopen the application and confirm the session and cached data remain available.

Uninstalling clears the device's cached session/data, pending offline mutations, permissions, and scheduled reminders. Data already synchronized to the backend remains available after signing in again.

## Updating the installer

Every update must retain:

- Application ID: `com.nom0mon.synchrofit`
- The same permanent signing key
- A higher build number in `pubspec.yaml`

For example:

```yaml
version: 1.0.1+2
```

Rebuild and distribute the replacement APK. Android can install it over the previous version without clearing local data when the application ID and signing certificate match.

For Google Play, build an Android App Bundle with the protected production signing configuration:

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://syncrofit-api.onrender.com
```

See [docs/android-qa-release.md](docs/android-qa-release.md) for release gates, signing constraints, and the device QA matrix.

## API overview

Protected routes require a Sanctum bearer token. Major routes include:

- `GET /api/health`
- Authentication: register, login, logout, forgot password, and password change
- Profile: `GET|POST|PUT /api/profile`
- Exercise library: `GET /api/exercises` and `GET /api/exercises/{exercise}`
- Workouts: list, create, generate, accept plan, and customize exercises
- Workout history: create, list, and statistics
- Private progress logs: list, create, show, retrieve image, and delete
- Community: posts, photos, likes, comments, and owner-authorized deletion

The definitions in [backend/routes/api.php](backend/routes/api.php) and the API tests are authoritative.
