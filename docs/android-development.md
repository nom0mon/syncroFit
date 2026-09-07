# Android development and onboarding

SyncroFit supports Android only. Contributors run and debug the Flutter client on an Android emulator or a physical Android device. Host operating systems may vary, but host, browser, and non-Android Flutter targets are not product runtimes and are not release-tested.

## Toolchain

The clean-checkout baseline used Flutter 3.44.0 stable, Dart 3.12.0, JDK 17, Gradle 9.1.0, Android Gradle Plugin 9.0.1, Kotlin 2.3.20, Android SDK 36, PHP 8.5.9, and Composer 2.10.2. The product supports Android API 24–35 and requires `compileSdk` 35 or newer. The current Composer lock requires PHP 8.4.1 or newer even though `backend/composer.json` permits older PHP 8.2 releases.

Install:

1. Flutter 3.44.0 stable and JDK 17.
2. Android Studio with Android SDK Platform 35 or newer, Android SDK Build-Tools, Android SDK Command-line Tools (latest), Android Emulator, and Platform-Tools.
3. API 24 and API 35 emulator images. Use an x86_64 image for local emulation; production device ABIs are `arm64-v8a` and `armeabi-v7a`.
4. PHP 8.4.1+, Composer 2.x, and MySQL 8.0+ for the runtime backend.

Verify setup:

```powershell
flutter --version
java -version
adb version
flutter doctor -v
flutter doctor --android-licenses
```

Do not proceed until `flutter doctor -v` reports a healthy Android toolchain, including installed command-line tools and accepted licenses.

## Restore the repository

From the repository root:

```powershell
flutter pub get --enforce-lockfile
Set-Location backend
composer install --no-interaction --prefer-dist --no-progress
Copy-Item .env.example .env
php artisan key:generate
```

Configure MySQL connection values in `backend/.env`, then initialize the local database:

```powershell
php artisan migrate --seed
```

Automated backend tests use in-memory SQLite and do not require the MySQL service.

## Start the local API

The Android client defaults to the deployed Render API. To use local Laravel, start it on port 8000:

```powershell
Set-Location backend
php artisan serve --host=127.0.0.1 --port=8000
```

Keep this process running. In the terminal used for the Android device, establish reverse port forwarding:

```powershell
adb reverse tcp:8000 tcp:8000
```

This maps the Android device's loopback port 8000 to the development host. Re-run it after reconnecting or restarting a device. Confirm mappings with `adb reverse --list`.

For remote devices where ADB reverse is unavailable, use an approved HTTPS development API and update the development-only API configuration. Never commit workstation IP addresses, credentials, or a release configuration that permits cleartext HTTP.

## Android emulator

Create an Android Virtual Device in Android Studio Device Manager. For normal development, use an API 35 phone image with Google APIs, at least one portrait profile, and an x86_64 system image. Also retain an API 24 AVD for minimum-version checks.

List and start emulators:

```powershell
flutter emulators
flutter emulators --launch <emulator-id>
flutter devices
```

After the emulator has finished booting:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Use the explicit device ID reported by `flutter devices`; do not rely on host-device auto-selection. Android Studio can configure additional cutout, navigation, orientation, resolution, and font-scale variants required by the QA matrix.

## Physical Android device

1. Enable Developer options by tapping **Build number** seven times in Android Settings.
2. Enable **USB debugging**. Use a data-capable USB cable and accept the computer's RSA authorization prompt.
3. On Windows, install the device manufacturer's USB driver if the device does not appear.
4. Verify the connection:

```powershell
adb devices
flutter devices
```

The device must appear as `device`, not `unauthorized` or `offline`. Then run:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Physical-device testing is required for camera/media providers, sharing, real network transitions, process restart, hardware decoding, display cutouts, and gesture-navigation insets. Wireless debugging may be used after initial pairing, but the same explicit device selection and API reachability checks apply.

## Native Android toolchain

Task 1.2 found native Android dependencies in the resolved Flutter graph and `android/app/build.gradle.kts` intentionally delegates `ndkVersion` to `flutter.ndkVersion`. Keep Android Studio's **NDK (Side by side)** component available and install the version requested by the pinned Flutter SDK if Gradle reports it missing. Do not hard-code a different NDK version.

There is no project `CMakeLists.txt`, `externalNativeBuild`, or explicit CMake version. No project-specific CMake setup is required. Do not add CMake configuration merely because transitive Flutter packages contain native code.

## Supported local commands

Run the app only against an Android target:

```powershell
flutter devices
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Run validation and local QA builds from the repository root:

```powershell
flutter analyze
flutter test --reporter compact
flutter build apk --debug
```

Run backend validation from `backend/`:

```powershell
php artisan test
```

Use `flutter build appbundle --release` only as part of the release procedure in `android-qa-release.md`. A debug APK is a local QA artifact, not a production release artifact.

## Known clean-checkout baseline issues

The captured baseline in `.kiro/specs/android-completion/clean-checkout-baseline.md` is not green: Flutter analysis and tests have existing failures, the full Laravel test command has a clean-checkout suite-directory defect, and the release build exits nonzero during native symbol stripping. The local machine used for that baseline was also missing Android command-line tools and verified licenses.

Treat these as blockers to resolve, not steps to skip. Never accept a partial AAB left behind by a failed command.
