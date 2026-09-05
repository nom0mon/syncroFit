# Android QA and release procedure

Android is SyncroFit's only supported runtime and release target. Every release candidate must pass automated gates, the Android emulator matrix, and the physical-device checks below. The authoritative locked values are in `.kiro/specs/android-completion/release-decisions.md`.

## Supported release envelope

- Android 7.0/API 24 minimum; Android 15/API 35 target; `compileSdk` 35 or newer.
- Production ABIs: `arm64-v8a` and `armeabi-v7a`.
- Supported window width: 320–1,280 dp on phones, tablets, and folded/unfolded single-window foldable layouts.
- Android App Bundle (`.aab`) is the only production artifact.
- Version comes from `pubspec.yaml` as `MAJOR.MINOR.PATCH+BUILD`; `BUILD` is a positive, monotonically increasing Android version code and is never reused.
- Artifact name: `synchrofit-android-<MAJOR.MINOR.PATCH>-<BUILD>-release.aab`.
- Local QA APKs must be debug builds and must include `qa` when retained or shared. Never publish a universal APK.

## Automated preflight

Use a clean checkout with the locked manifests. Restore dependencies:

```powershell
flutter pub get --enforce-lockfile
Set-Location backend
composer install --no-interaction --prefer-dist --no-progress
Set-Location ..
```

Run the required gates; any nonzero exit blocks release:

```powershell
flutter analyze
flutter test --reporter compact
Set-Location backend
php artisan test
Set-Location ..
flutter build appbundle --release
```

The supported release build command is exactly:

```powershell
flutter build appbundle --release
```

Its canonical output is `build/app/outputs/bundle/release/app-release.aab`. A successful protected release job must copy that output to the locked versioned name. Do not rename or publish an artifact unless the build command exits zero and every earlier gate passes.

For local device QA only:

```powershell
flutter build apk --debug
```

Install/run on a selected Android device with `flutter run -d <android-device-id>` or install the debug artifact with `adb install -r <qa-apk-path>`. Local QA does not substitute for the protected signed release build.

## Signing and artifact controls

Production uses Google Play App Signing. CI signs the AAB with the organization upload key supplied only through masked, protected release-environment secrets for an approved release tag. Keystores, aliases, passwords, generated signing properties, and production object credentials must never be committed, logged, cached, or published as artifacts.

The release job must use an ephemeral keystore, restrict access to the build process, remove signing files after the build, and publish only the versioned AAB plus approved checksums/metadata. Debug signing is forbidden. Local release signing is limited to an approved recovery exercise using environment-injected secrets and untracked files.

Before approval, verify:

1. application ID and namespace are `com.synchrofit.app`;
2. min/target SDK and ABI filters match the supported envelope;
3. `versionName` and `versionCode` match `pubspec.yaml` and the build number has never been used;
4. the AAB is upload-key signed rather than debug signed;
5. the filename exactly follows the locked convention;
6. the build and all test commands exited zero;
7. no signing or application secrets appear in logs or artifacts.

## Emulator matrix

Every release candidate must pass all rows in portrait and landscape, at 100% and 200% font scale. Exercise keyboard-open forms and denied-then-granted permissions where applicable.

| ID | API and viewport | Required focus |
| --- | --- | --- |
| E1 | API 24, 320 × 568 dp | Minimum OS/width, 3-button navigation |
| E2 | API 28, 360 × 720 dp | Tall cutout, keyboard-open forms |
| E3 | API 29, 412 × 915 dp | Gesture navigation, cutout/insets |
| E4 | API 33, 600 × 960 dp | First tablet breakpoint, media selection |
| E5 | API 35, 412 dp folded and 840 dp unfolded | Fold/rotate transitions without state loss |
| E6 | API 35, 1,280 × 800 dp and rotated | Maximum width and constrained readable content |

At 200% font scale, exercise registration/login, dashboard, workout generation and active workout, exercise library/detail, progress/photos, community feed/composer/detail/comments, profile edit, settings, dialogs, and bottom navigation.

## Physical-device matrix

| ID | Required device | Required focus |
| --- | --- | --- |
| P1 | API 24–28 ARM phone, 320–360 dp | Install/startup, rotation, 3-button navigation, camera, offline/reconnect, constrained-memory restart |
| P2 | API 33–35 ARM64 phone, 360–430 dp, real cutout | Gestures, 200% font, keyboard/insets, camera, media picker, upload/retry/delete/share, all released tabs |
| P3 | API 33–35 ARM64 tablet, at least 600 dp | Rotation, 200% font, adaptive lists/grids, dialogs, charts, community, comparison |
| P4 | API 33–35 foldable when available | Fold/unfold and rotation during forms, workout, upload, comparison, and composer |

If foldable hardware is unavailable, E5 remains mandatory and the missing P4 evidence must be recorded as a release risk.

## Functional and accessibility checks

A candidate is blocked by any platform exception, Flutter layout overflow, clipped or keyboard-obscured primary action, target smaller than 48 dp, unsafe cutout/gesture inset, state loss during fold/rotation, or failure at 200% font scale.

On a fresh install, verify:

- registration, login, logout, and account switching;
- every released bottom-navigation tab and reachable route;
- offline cache behavior, queued mutation, reconnect, and process restart;
- camera/media selection, permission denial/retry/settings guidance, upload retry, authorized media viewing, deletion, comparison, and explicit Android sharing when those release features are enabled;
- community persistence and user-specific like state when the remote community implementation is enabled;
- TalkBack labels/announcements, logical focus order, contrast, and 48 dp interactive targets;
- no production provider resolves to mock-only community or consultation data and no removed route remains reachable.

Use `docs/android-responsive-layout.md` for the shared width, spacing, text, chart, and hit-target rules.

## Backend and data release checks

Before deployment approval:

- run the full Laravel suite with `php artisan test`;
- test migrations forward and rollback against a production-like MySQL 8 database;
- verify authorization/cross-user isolation, rate limits, deletion, and idempotency for applicable release features;
- verify private media storage, retention, deletion reconciliation, and privacy/store disclosures before enabling progress photos;
- verify community reporting, moderation operations, audit trail, terms/guidelines, monitoring, and controlled-beta approvals before enabling community beta.

## Current blockers

The clean-checkout baseline is evidence, not a waiver. At the captured baseline:

- `flutter analyze` reports existing warnings/info;
- `flutter test` has existing failures;
- `php artisan test` fails before execution because the tracked checkout lacks the configured `tests/Unit` directory, although the Feature suite passes;
- `flutter build appbundle --release` exits nonzero during native symbol stripping and leaves a partial, unvalidated AAB;
- production application identity, ABI filtering, protected upload-key signing, and versioned artifact publication are not yet configured;
- Android SDK command-line tools/license verification were missing on the baseline host.

A release cannot be approved until these blockers and every applicable implementation gate in `release-decisions.md` are closed.