# Clean-checkout Android build baseline

Status: **Baseline captured; release gates are not green**  
Scope: `android-completion` task 1.3  
Source: `PRD.md` section 1 acceptance criteria and Success metrics  
Run completed: 2026-08-26 UTC

This record captures dependency restoration and validation from a detached, clean checkout of commit `e0fe6a3a3a04981f4acfd086178c670b35c8eb82` (`README - SyncroFit v1.1`). The active workspace contained pre-existing and concurrent uncommitted work, so all commands ran in the isolated worktree `C:\repos\synchrofit\syncroFit-task-1-3-baseline`. No active-workspace source, dependency, task-status, or generated file was reset or overwritten.

## Reproduction boundary

The baseline used the committed manifests and lockfiles at the reference commit, not the concurrently changing active-workspace manifests. Dependency restoration used:

```powershell
flutter pub get --enforce-lockfile
composer install --no-interaction --prefer-dist --no-progress
```

Both commands completed with exit code 0. Flutter reported 41 newer packages incompatible with current constraints; this is informational because `--enforce-lockfile` retained the committed resolution. Composer installed 113 packages from `composer.lock` with 0 updates and 0 removals. Restore/build generation modified unsupported-platform plugin registrants and Composer cache files only inside the disposable worktree; these are generated side effects and were not copied to the active workspace.

Reference lockfile SHA-256 values:

- `pubspec.lock`: `2AB150B01E987E54808132B0E69A1387A91C0842A83B3135EA43183F7F9E1823`
- `backend/composer.lock`: `A158E94B78C4E8DB311882DF7657092DF9461541BA85A4304A218460A2F2191D`

## Toolchain and database baseline

| Component | Baseline used | Repository/documented constraint | Result or drift |
| --- | --- | --- | --- |
| Host | Windows 10 Pro 22H2, build 19045.6466 | Windows local baseline | Observed by `flutter doctor -v`. |
| Flutter | 3.44.0 stable, framework `559ffa3f75` | Lock requires Flutter `>=3.44.0`; `.metadata` records stable channel | Exact observed baseline. |
| Dart | 3.12.0 | Lock requires Dart `>=3.12.0 <4.0.0` | Exact observed baseline. |
| Android SDK | 36.0.0 | Release decision targets API 35 and requires `compileSdk >=35`; Gradle currently delegates SDK values to Flutter | Installed SDK satisfies the minimum, but `flutter doctor -v` reports missing `cmdline-tools` and unknown license status. |
| JDK | Temurin OpenJDK 17.0.15+6 | Android compile options and Kotlin JVM target are Java 17 | Exact observed baseline. |
| Gradle | 9.1.0 | Wrapper pins 9.1.0 | Exact committed wrapper. |
| Android Gradle Plugin | 9.0.1 | Pinned in `android/settings.gradle.kts` | Exact committed plugin. |
| Kotlin Android plugin | 2.3.20 | Pinned in `android/settings.gradle.kts` | Exact committed plugin. |
| PHP | 8.5.9 CLI | `composer.json` documents `^8.2`; backend README says 8.2+ | Baseline used the previously observed version. The current lock includes packages requiring PHP 8.4.1+, so PHP 8.2 alone is not sufficient to reproduce this lock. |
| Composer | 2.10.2 | Backend README says Composer 2.x | Exact observed baseline. |
| Test database | SQLite 3.53.2 in memory through Laravel's `testing` connection | `phpunit.xml` sets `DB_CONNECTION=testing`, `DB_DATABASE=:memory:` | PDO drivers `mysql` and `sqlite` are loaded; no external database is required for automated tests. |
| Runtime database | Not exercised; MySQL CLI is not installed/on `PATH` | Backend README requires MySQL 8.0+ | Runtime MySQL version and migrations remain unverified in this environment. |

## Exact command outcomes

| Command | Exit | Outcome |
| --- | ---: | --- |
| `flutter pub get --enforce-lockfile` | 0 | Restored the committed Flutter resolution; 41 constrained packages have newer incompatible versions. |
| `composer install --no-interaction --prefer-dist --no-progress` | 0 | Installed 113 locked packages, 0 updates, 0 removals; Laravel package discovery completed. |
| `flutter analyze` | 1 | **Fail:** 47 issues in 55.5 seconds: 45 info findings and 2 warnings. The warnings are unused `dart:convert` and `dart:ui` imports in existing tests. |
| `flutter test --reporter compact` | 1 | **Fail:** 353 passed and 6 failed in approximately 32 seconds. Failures reproduce the task 1.2 baseline: missing Edit Profile navigation text, an unstubbed recommendation API mock returning `null`, incomplete simultaneous profile validation errors, incorrect offline profile PATCH dirty fields, and two profile dirty-field reversion properties (including shrunk input `2`, expected `{age}`, actual `{name, age}`). |
| `php artisan test` | 1 | **Fail before test execution:** `phpunit.xml` declares `tests/Unit`, but a clean checkout has no tracked `backend/tests/Unit` directory. This is a clean-checkout configuration defect. |
| `php artisan test --testsuite=Feature` | 0 | Diagnostic: all 63 committed feature/property tests passed with 10,973 assertions in 109.65 seconds using in-memory SQLite. This does not make the required full command green. |
| `flutter build appbundle --release` | 1 | **Fail:** Gradle `bundleRelease` ran for 177.6 seconds, then Flutter failed to strip debug symbols from native libraries. The build also warned that `CupertinoIcons` font assets were referenced but unavailable. |
| `flutter doctor -v` | 0 | Diagnostic completed with one unhealthy category: Android command-line tools missing and Android license status unknown. |

## Failure ownership

### Pre-existing at the reference commit

- All 47 analysis findings and all 6 Flutter test failures are present in the clean reference checkout and match task 1.2's earlier remediation baseline.
- The release build's native-symbol-strip failure and Cupertino icon warning reproduce task 1.2.
- The missing `backend/tests/Unit` directory is also pre-existing at the reference commit. It was masked outside a clean checkout by an untracked/local empty directory; the committed feature suite itself remains green.
- Missing Android command-line tools/license verification, example application ID, debug release signing, unversioned output filename, and unsupported-platform generation are pre-existing configuration gaps.

### Introduced by task 1.3 or this plan

None. Task 1.3 changed documentation only. The active workspace's concurrent implementation edits were excluded from the isolated baseline and were not evaluated, so this record makes no pass/fail claim about them.

## AAB and current version metadata

`pubspec.yaml` is the current committed version source:

- Product version: `1.0.0+1`
- Android `versionName`: `1.0.0`
- Android `versionCode`: `1`
- Current application ID/namespace: `com.example.synchrofit`
- Current release signing: debug signing configuration

The failed build emitted:

- Relative path: `build/app/outputs/bundle/release/app-release.aab`
- Baseline worktree path: `C:\repos\synchrofit\syncroFit-task-1-3-baseline\build\app\outputs\bundle\release\app-release.aab`
- Size: 66,328,682 bytes
- SHA-256: `ACA279A5FFA270C3C888D01042209C6D70B1CA1B6416B280B9B8B84826BB6002`

Because `flutter build appbundle --release` exited 1 after symbol-strip validation, this file was a **partial/unvalidated artifact**, not a releasable AAB. It was also not named according to the approved release convention `synchrofit-android-1.0.0-1-release.aab`. The disposable worktree and partial artifact were removed after their path, size, and hash were recorded; the canonical relative output location remains the path above.

## PRD gate assessment

- Section 1's requirement that `flutter build appbundle --release` complete and generate a versioned artifact is **not met**.
- The Success metric requiring the Android release build and full Flutter/Laravel suites to pass from a clean checkout is **not met**.
- No conclusion is made here about fresh-install device flows, responsive layout coverage, upload success, community persistence, or production mock calls; those require their later implementation and QA tasks.

## Blocking follow-up

1. Install Android SDK command-line tools, accept/verify licenses, and resolve native debug-symbol stripping before accepting any generated AAB.
2. Track an empty `backend/tests/Unit` directory with a placeholder or remove/conditionally configure that nonexistent suite so `php artisan test` works from a clean checkout.
3. Resolve the 47 Flutter analysis findings and 6 pre-existing Flutter test failures.
4. Add the missing Cupertino icon dependency/assets or remove its icon references.
5. Replace the example Android identity and debug release signing, enforce approved SDK/ABI values, and emit the approved versioned AAB filename through protected release automation.
6. Pin/document a PHP version compatible with the committed Composer lock and validate MySQL 8 runtime migrations separately from SQLite tests.
