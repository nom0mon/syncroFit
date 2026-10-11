# SyncroFit — Change Summary (2026-10-10)

This document summarizes the bug fixes, the color-palette redesign, the API
configuration fix, the release build, and the verification performed in this
session.

## Overview

| Area | Status |
|------|--------|
| D1 — 0-exercise workout completion rejected | Fixed |
| D2 — regenerate / stale-draft 404-422 | Fixed |
| D3 — preference change left stale generator state | Fixed |
| Color palette redesign (navy / blue / lime) | Done |
| Hardcoded localhost API base URL (culprit) | Fixed |
| Release APK rebuilt and pointed at Render | Done |

Verification: `flutter analyze` clean, `flutter test` 521 passed,
`php artisan test` 108 passed (10,809 assertions).

---

## Bug fixes

### D1 — Validation failed when completing a workout with 0 exercises done

**Root cause.** When a user skipped every exercise, the client sent
`exercises_completed: []`. The server rule `required|array` rejects an empty
array, returning HTTP 422. The summary screen surfaced this as a misleading
"check your connection" message.

**Changes.**
- `backend/app/Http/Controllers/WorkoutHistoryController.php`
  - `exercises_completed` validation changed from `required|array` to
    `present|array` (accepts `[]`, still rejects a missing key).
- `lib/features/workout/screens/workout_summary_screen.dart`
  - Save-failure message made neutral ("Please retry.") instead of blaming
    connectivity.
- `backend/tests/Feature/WorkoutHistoryEmptyExercisesTest.php` (new)
  - Asserts a zero-exercise completion is accepted (201) and a missing
    `exercises_completed` key is still rejected (422).

### D3 — Changing preferences in the generator left stale client state

**Root cause.** After a plan was generated, changing fitness level, goal, or
workout environment left the on-screen draft (and its server `plan_id`) in
state. Accepting or customizing that stale draft could hit a 404 (server had
pruned it) or a 422 (an exercise was no longer valid for the new environment).

**Changes.**
- `lib/features/workout/providers/workout_generator_provider.dart`
  - `setFitnessLevel`, `setFitnessGoal`, and `setWorkoutPreference` now call a
    new `_withClearedStaleDraft(...)` helper that resets the generator to
    `idle` and clears `generatedWorkouts` whenever a draft exists, forcing an
    explicit regenerate before a plan can be accepted.

### D2 — Regenerate / stale-draft reference causing 404-422

**Root cause.** `acceptPlan()` always returned the generator to the
`generated` state on failure, so a stale/already-pruned draft could be
re-accepted in a loop.

**Changes.**
- `lib/features/workout/providers/workout_generator_provider.dart`
  - `acceptPlan()` failure handling now distinguishes a stale draft
    (`NotFoundError`, or `ServerError` with status 404 or 422) from a transient
    error. A stale draft resets the generator to `idle` with the message
    "This plan is no longer available. Please generate a new one." A transient
    5xx keeps the draft so the user can retry.
- `test/features/workout/workout_generator_provider_test.dart` (new)
  - Covers D3 (preference change clears the draft) and D2 (404 resets to idle,
    500 keeps the draft) with a fake repository.

---

## Color palette redesign

New brand palette:

| Role | Hex |
|------|-----|
| Navy (dark surface / text on light) | `#142D4E` |
| Blue (primary interactive) | `#3478F6` |
| Lime (accent / highlight) | `#C6F135` |

**Changes.**
- `lib/core/theme/app_colors.dart` (rewritten)
  - Added `brandNavy`, `brandBlue`, `brandLime`, plus navy-derived surface,
    card, and border tones. All previously-used constant names were preserved
    (greys remapped to navy-tinted neutrals) so no call sites broke.
- `lib/core/theme/app_theme.dart`
  - Light theme: blue primary, navy on-surface text, lime tertiary.
  - Dark theme: navy scaffold, blue primary, lime secondary/tertiary accent,
    white on-primary for contrast.
- `lib/core/theme/component_themes.dart`
  - Primary elevated buttons now brand blue; light input focus border blue;
    dark cards use navy fill and navy border.
- `test/core/theme/brand_palette_test.dart` (renamed from
  `dark_theme_greyscale_test.dart`)
  - The old achromatic (greyscale) dark-theme property was intentionally
    superseded by the chromatic brand palette. The test now pins the three
    brand hex values and verifies the theme wiring.
- `test/features/auth/bug_condition_exploration_test.dart`
  - Login focused-border assertion updated from `grey900` to `focusBorder`
    (dark input theme focus = brand blue).
- `test/shared/widgets/edge_fade_gradient_test.dart`
  - Corrected to expect a transparent version of the scaffold color (the
    widget's documented behavior) rather than transparent black; the navy
    scaffold exposed the previously-coincidental assertion.

---

## API configuration fix (culprit)

**Root cause.** `ApiConfig.baseUrl` was hardcoded to `http://127.0.0.1:8000`
and never read the documented `--dart-define=API_BASE_URL`. Any build that
forgot the flag shipped pointing at localhost.

**Change.**
- `lib/core/network/api_config.dart`
  - `baseUrl` now reads `String.fromEnvironment('API_BASE_URL', ...)` with a
    release-safe fallback of `https://syncrofit-api.onrender.com`, so a
    forgotten flag can never ship a localhost build.

---

## Release build

- Command:
  `flutter build apk --release --dart-define=API_BASE_URL=https://syncrofit-api.onrender.com`
  (preceded by `flutter clean` + `flutter pub get`).
- Output: `build/app/outputs/flutter-apk/app-release.apk` — 403.8 MB,
  production-signed with the keystore at
  `C:\syncrofit-keys\syncrofit-release.jks`.
- Backend connection verified: `https://syncrofit-api.onrender.com` is embedded
  in the compiled `libapp.so` (baked in via both the config default and the
  build-time `--dart-define`). No localhost fallback path exists in this build.

### Notes / follow-ups (not changed in this session)

- Non-fatal Gradle warning: `camera_android_camerax` and `flutter_timezone`
  still apply the Kotlin Gradle Plugin the legacy way; future Flutter versions
  may require upgrading those plugins.
- APK size (403.8 MB) is driven by ~340 MB of bundled videos in
  `assets/videos/`. Consider an app bundle (`.aab`) with on-demand asset
  delivery, or network-delivered videos, to reduce download size.
- The backend D1 change is committed in the working tree and tested, but is
  **not deployed** to Render. Deploying requires pushing the backend to the
  branch Render builds from. The APK is the Android client and is not deployed
  to Render.

---

## Files changed

### Backend
- `backend/app/Http/Controllers/WorkoutHistoryController.php` (modified)
- `backend/tests/Feature/WorkoutHistoryEmptyExercisesTest.php` (new)

### Flutter — source
- `lib/features/workout/providers/workout_generator_provider.dart` (modified)
- `lib/features/workout/screens/workout_summary_screen.dart` (modified)
- `lib/core/network/api_config.dart` (modified)
- `lib/core/theme/app_colors.dart` (rewritten)
- `lib/core/theme/app_theme.dart` (modified)
- `lib/core/theme/component_themes.dart` (modified)

### Flutter — tests
- `test/features/workout/workout_generator_provider_test.dart` (new)
- `test/core/theme/brand_palette_test.dart` (renamed from
  `dark_theme_greyscale_test.dart`, rewritten)
- `test/features/auth/bug_condition_exploration_test.dart` (modified)
- `test/shared/widgets/edge_fade_gradient_test.dart` (modified)

---

## Verification results

- `flutter analyze` — No issues found.
- `flutter test` — 521 passed.
- `php artisan test` — 108 passed (10,809 assertions).
- Release APK built and confirmed to embed the Render backend URL.
