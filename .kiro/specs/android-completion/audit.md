# Android Completion Audit and Remediation Baseline

This artifact records task 1.2 against the root `PRD.md` (Context/current state, §1, and §5). The spec has an empty `requirements.md` and no `.config` or `design.md`; `tasks.md` explicitly identifies the PRD as the release source of truth. No task status metadata was changed.

## Platform, documentation, and tooling audit

Unsupported Flutter target directories are present: `ios/`, `web/`, `windows/`, `linux/`, and `macos/`. Their project files, assets, runners, CMake/Xcode configuration, and generated registrants are self-contained platform output and can be removed as part of task 2.1.

First-party references that must be remediated with that removal:

| Location | Finding | Disposition |
| --- | --- | --- |
| `README.md` | Describes a mobile/web client, lists `sqflite_common_ffi_web`, and recommends `flutter run -d chrome`. | Make Android-only in task 2.3. |
| `pubspec.yaml` | Direct runtime dependency on `sqflite_common_ffi_web`; launcher config retains `ios: false`. | Remove the web dependency and obsolete iOS key, then regenerate metadata. |
| `lib/main.dart` | Imports `kIsWeb` and `sqflite_ffi_web.dart`, switches to `databaseFactoryFfiWeb`, and documents web fallback behavior. | Remove the web branch/imports for Android-only startup. |
| `lib/data/caching/caching_providers.dart` | Web-only fallback is mentioned in comments; fallback behavior itself is platform-neutral. | Update comments after web removal; retain remote fallback if still desired. |
| `lib/core/network/api_config.dart` | Retains an iOS-simulator comment. It also uses `127.0.0.1` although its Android-emulator comment specifies `10.0.2.2`. | Remove iOS guidance and resolve Android base URL configuration separately. |
| `lib/core/network/token_storage.dart` | Documents iOS Keychain and Web localStorage. | Make documentation Android-specific. |
| `.metadata` | Tracks all unsupported targets and an unmanaged `ios/Runner.xcodeproj/project.pbxproj`. | Regenerate/update after deleting target directories. |
| `.gitignore` | Contains an iOS last-build rule. | Remove obsolete unsupported-platform rules. |
| `.flutter-plugins-dependencies` | Generated metadata lists iOS, macOS, Linux, Windows, and Web plugins and absolute local cache paths. | Do not hand-edit; regenerate after dependency/platform cleanup. |
| `.dart_tool/chrome-device/` | Ignored local Chrome runtime state. | Generated state only; remove locally if desired, never treat as release input. |

No unsupported `.ipa`, `.dmg`, `.msix`, AppImage, web bundle, or desktop release artifact/reference was found in maintained source, docs, or automation. The only requested release artifact is Android `.aab`; the current build directory is ignored.

### Automation deletion gate

- There is no `.github/` directory, CI workflow, root `scripts/` directory, release script, Makefile, Dockerfile, or Kiro hook.
- Kiro content under `.kiro/` consists of specs only.
- Laravel Composer scripts perform Laravel package discovery/publishing and environment/key setup only; they do not reference Flutter platform directories.
- Android Gradle wrapper/configuration references only `android/` and the Flutter project root.
- Repository searches found no maintained shell, PowerShell, batch, YAML, or JSON automation that consumes `ios/`, `web/`, `windows/`, `linux/`, or `macos/`.

**Conclusion:** no repository automation depends on the unsupported platform directories. Platform deletion is clear from an automation perspective after the source/configuration references above are removed. `.metadata` is a tooling cleanup item, not a dependency that blocks deletion.

## Dependency, generated-plugin, and Android native audit

### Direct and transitive packages

- `sqflite_common_ffi_web` is the only direct web-only runtime dependency. Its only production import is the `kIsWeb` branch in `lib/main.dart`; Android runtime code does not need it.
- It pulls `sqflite_common_ffi`, `sqlite3`, hooks/code assets, and `native_toolchain_c` into the main dependency graph. The Android release staging output contains `libsqlite3.so`, showing that this web dependency currently affects Android native output.
- `sqflite_common_ffi` is also a direct **dev** dependency used by host-side database tests. Do not remove the dev dependency merely because desktop runtime targets are removed unless those tests are migrated to another database strategy.
- Federated packages (`flutter_secure_storage`, `path_provider`, `shared_preferences`, `connectivity_plus`, and `sqflite`) resolve desktop/web implementations in the lock/generated metadata. Their parent packages are used on Android; unsupported implementations should disappear from generated platform registration when directories are removed but are not, by themselves, reasons to remove the Android-capable parent package.

### Plugin registrants

| Platform | Registered plugins |
| --- | --- |
| Android | `connectivity_plus`, `flutter_secure_storage`, `jni`, `jni_flutter`, `shared_preferences_android`, `sqflite_android` |
| iOS | connectivity, secure storage, shared preferences foundation, sqflite Darwin |
| macOS | connectivity, secure storage macOS, shared preferences foundation, sqflite Darwin |
| Linux | secure storage Linux |
| Windows | connectivity and secure storage Windows |
| Web | Listed in `.flutter-plugins-dependencies`: connectivity, secure storage Web, shared preferences Web |

Android's `jni`/`jni_flutter` registrations are transitive through `path_provider_android`. Release staging contains `libdartjni.so`, `libdatastore_shared_counter.so`, and `libsqlite3.so` alongside Flutter/app libraries for `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64`.

### Gradle, NDK, and CMake

- `android/app/build.gradle.kts` sets `ndkVersion = flutter.ndkVersion`.
- No `externalNativeBuild`, project `CMakeLists.txt`, or explicit CMake version is configured under `android/`.
- Native/code-asset requirements currently come from dependencies: `sqlite3`/`native_toolchain_c`, JNI used by `path_provider_android`, and shared-preferences native output.
- Keep the Flutter NDK configuration until task 2.1 removes `sqflite_common_ffi_web`, regenerates dependencies, and proves a release build no longer requires it. Do not add project CMake configuration based on the current audit.
- Android Gradle Plugin is `9.0.1`, Kotlin plugin is `2.3.20`, Java compatibility is 17, and the app still uses placeholder namespace/application ID `com.example.synchrofit` with debug signing for release.

## Production provider bindings

| Provider | Production binding | Status |
| --- | --- | --- |
| `communityRepositoryProvider` | `MockCommunityRepository` | **Release blocker:** routed Community tab serves in-memory mock data. |
| `consultationRepositoryProvider` | `MockConsultationRepository` | **Release blocker:** trainer/booking routes serve mock data. |
| `authRepositoryProvider`, `settingsAuthRepositoryProvider` | `RemoteAuthRepository` | Remote Laravel binding. |
| Profile, exercise, workout, workout-history, dashboard, and progress repository providers | Caching repositories wrapping remote repositories, with remote fallback | Production remote/caching binding. |

Other mock repository classes exist under `lib/data/mock/`, but repository-wide production-source searches found no other production provider resolving to them.

## Route and screen inventory

### Routed shell tabs

The bottom navigation and `StatefulShellRoute` expose exactly four tabs:

1. `/dashboard` — `DashboardScreen`
2. `/exercises` — `ExerciseAndRecommendationsScreen`
3. `/progress` — `ProgressSummaryScreen`
4. `/community` — `FeedScreen` (currently mock-backed)

### Other routed screens

- Auth: `/login`, `/register`, `/forgot-password`.
- Onboarding: `/profile-setup`, `/assessment/:step` (BMI, physical info, and goals selected by step).
- Dashboard descendants: workout generator, workout detail, active workout, rest timer, and summary.
- Exercise descendant: exercise detail.
- Community descendant: post detail.
- Settings: main settings, notification settings, change password, profile view, and profile edit.
- Consultation: trainer list, trainer profile, and booking form.
- Error handling: `PageNotFoundScreen`.

### Dead, unreachable, or inconsistent routes

- `RouteNames.sessionDetail` (`/progress/session/:id`) is dead: there is no matching `GoRoute` or production navigation call.
- `/notifications` is registered but only renders “Notifications have been removed.” No production navigation enters it; it remains deep-link-only dead UI.
- `/settings/trainers` has no inbound production navigation. Trainer detail and booking are reachable only after entering that deep-link-only root, so the consultation route set is not reachable through released UI.
- `SearchScreen` exists as a placeholder but has no route, provider, navigation destination, or import from the router.
- Child constants for workout, exercise detail, post detail, notification settings, change password, profile, edit profile, and trainer routes are declaration-only because `app_router.dart` and navigation callsites hard-code equivalent paths. Those constants are inconsistent/unused rather than semantically dead where a matching hard-coded route exists.
- Settings and dashboard expose notification **settings**, not the removed `/notifications` inbox. Change Password is routed but is known from PRD §5 to return 501 in the remote repository until implemented.

## Remediation baseline

Toolchain observed: Flutter `3.44.0` stable, Dart `3.12.0`, Java `17.0.15`, PHP `8.5.9`, Android SDK `36.0.0`, app version `1.0.0+1`.

| Command | Result | Baseline findings |
| --- | --- | --- |
| `flutter analyze` | **FAIL**, exit 1 | 47 findings: 45 info and 2 warnings. Warnings are unused imports in `workout_history_dao_date_range_properties_test.dart` and `body_silhouette_test.dart`; info findings include deprecated Flutter APIs, unnecessary imports, missing `const`, and documentation/style lints. |
| `flutter test` | **FAIL**, exit 1 | 353 passed, 6 failed. Observed failures include an unstubbed `RemoteWorkoutRepository.generateRecommendation` mock returning null, an edit-profile navigation test looking for a nonexistent “Edit Profile” settings row, profile validation not reporting expected simultaneous errors, and the dirty-field property shrinking to input `2` with expected `{age}` but actual `{name, age}`. |
| `php artisan test` | **PASS**, exit 0 | 63 tests passed with 10,761 assertions in 95.29 seconds. No current Laravel remediation failure. |
| `flutter build appbundle --release` | **FAIL**, exit 1 | Gradle `bundleRelease` ran for 162.7 seconds, then Flutter failed while stripping debug symbols from native libraries. It also warned that Cupertino icon font assets were referenced but unavailable. |
| `flutter doctor -v` | Diagnostic | Android toolchain reports missing `cmdline-tools` and unknown Android license status; all other reported categories pass. |

The failed build left `build/app/outputs/bundle/release/app-release.aab`, but because the command exited nonzero after native symbol-strip validation, this is a partial/unvalidated artifact and must not be treated as a successful release baseline.

## Remediation blockers and follow-up checks

1. Install Android SDK command-line tools and accept/verify licenses, then rerun the release build.
2. Remove the production web dependency/branch and regenerate plugin/dependency metadata; verify whether `libsqlite3.so` and the NDK requirement disappear from release output while host tests still work.
3. Resolve the 47 analysis findings and 6 Flutter test failures as pre-existing baseline debt.
4. Replace/remove the two production mock bindings and dead/unreachable routes under the PRD §5 tasks.
5. Replace hard-coded child paths with `RouteNames` or remove the unused constants so route declarations and navigation cannot drift.
6. Configure the production Android application ID, release signing, API levels/ABIs, and artifact naming under task 1.1/Android delivery tasks; current release signing uses the debug key.
