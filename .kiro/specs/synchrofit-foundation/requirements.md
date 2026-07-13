# Requirements Document

## Introduction

SynchroFit Foundation establishes the project scaffolding for a fitness application consisting of an Android-only Flutter mobile client and a Laravel 12 REST API backend backed by MySQL 8. This spec covers project initialization, authentication infrastructure, initial database schema, and local development setup — providing a working baseline for future feature development.

## Glossary

- **Flutter_App**: The Android-only Flutter mobile application (`synchrofit_app`), targeting Android 10 (API level 29) and above.
- **Laravel_API**: The Laravel 12 PHP backend application (`synchrofit_api`) serving a REST API.
- **Database**: The MySQL 8 relational database used by the Laravel_API.
- **Sanctum**: Laravel Sanctum, the token-based API authentication package used for issuing and validating API tokens.
- **Health_Endpoint**: The GET /api/health route that confirms the Laravel_API is running.
- **User**: A registered account in the system.
- **User_Profile**: Extended personal and fitness information associated with a User (age, height, weight, gender, fitness goal, fitness level, workout preference, availability).
- **Clean_Architecture**: A folder structure separating concerns into core, features, data, domain, and presentation layers.
- **Migration**: A Laravel database migration file that defines or modifies database schema.

## Requirements

### Requirement 1: Flutter Project Initialization

**User Story:** As a developer, I want a properly structured Flutter project configured for Android-only builds, so that I can begin building Android features without iOS overhead.

#### Acceptance Criteria

1. THE Flutter_App SHALL be initialized as a Flutter project named `synchrofit_app` with the project name set to `synchrofit_app` in `pubspec.yaml`.
2. THE Flutter_App SHALL contain a Clean_Architecture folder structure with the directories: `lib/core`, `lib/features`, `lib/data`, `lib/domain`, and `lib/presentation`.
3. THE Flutter_App SHALL target Android 10 (API level 29) as the minimum SDK version and API level 34 as the compile SDK version in the Android build configuration.
4. WHEN the Flutter_App is launched on an Android emulator, THE Flutter_App SHALL display a home screen containing the visible text "SynchroFit" as the only content.
5. THE Flutter_App SHALL build successfully using the `flutter build apk` command without errors.
6. THE Flutter_App SHALL include a `.gitignore` file configured for Flutter projects that excludes build artifacts, IDE files, and platform-generated files.
7. THE Flutter_App SHALL be configured for Android-only builds by removing or excluding the `ios`, `web`, `macos`, `windows`, and `linux` platform directories from the project.

### Requirement 2: Laravel API Project Initialization

**User Story:** As a developer, I want a Laravel 12 API project with health-check functionality, so that I can verify the backend is operational and begin adding API routes.

#### Acceptance Criteria

1. THE Laravel_API SHALL be initialized as a Laravel 12 project named `synchrofit_api`.
2. THE Laravel_API SHALL use API-only routing via `routes/api.php`.
3. WHEN a GET request is sent to `/api/health`, THE Health_Endpoint SHALL respond with HTTP status 200, Content-Type `application/json`, and a JSON body containing a `status` field with value `"ok"`.
4. THE Laravel_API SHALL include CORS configuration that permits requests from `http://localhost:*` origins, allows methods GET, POST, PUT, PATCH, DELETE, and OPTIONS, and allows headers Content-Type, Authorization, X-Requested-With, and Accept.
5. THE Laravel_API SHALL include a `.gitignore` file configured for Laravel projects that excludes the `vendor` directory, `.env` file, compiled assets, and storage logs.
6. THE Laravel_API SHALL start successfully using `php artisan serve` and respond to HTTP requests on the default port 8000.

### Requirement 3: MySQL 8 Database Configuration

**User Story:** As a developer, I want the database connection preconfigured with placeholder credentials, so that I can quickly set up a local MySQL instance and run migrations.

#### Acceptance Criteria

1. THE Laravel_API SHALL include a `.env.example` file with MySQL 8 connection placeholders for `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD`, where `DB_HOST` defaults to `127.0.0.1`, `DB_PORT` defaults to `3306`, `DB_USERNAME` defaults to `root`, and `DB_PASSWORD` defaults to an empty string.
2. THE Laravel_API SHALL configure the default database connection as `mysql` in the `config/database.php` file.
3. THE `.env.example` file SHALL set `DB_DATABASE` to `synchrofit` as the default database name.
4. THE `.env.example` file SHALL NOT contain real credentials or secrets; all credential values SHALL be empty strings or clearly placeholder values (e.g., `root` for username, empty string for password).
5. WHEN a developer copies `.env.example` to `.env` and configures a running MySQL 8 instance with the specified credentials, THEN THE Laravel_API SHALL successfully establish a database connection without modification to `config/database.php`.

### Requirement 4: Laravel Sanctum Authentication

**User Story:** As a developer, I want token-based API authentication configured, so that future endpoints can be protected using Sanctum API tokens.

#### Acceptance Criteria

1. THE Laravel_API SHALL have Laravel Sanctum installed as a Composer dependency.
2. THE Laravel_API SHALL include the Sanctum configuration file published at `config/sanctum.php`.
3. THE Laravel_API SHALL apply the Sanctum middleware to the API route group and the User model SHALL use the `HasApiTokens` trait so that token-authenticated routes are available.
4. WHEN a request is sent to a protected route without a valid Sanctum token (missing, expired, or revoked), THE Laravel_API SHALL respond with HTTP status 401 and a JSON body containing a `message` field.
5. THE Laravel_API SHALL include a `personal_access_tokens` migration that creates the table required by Sanctum for token storage.

### Requirement 5: Users and Profiles Database Schema

**User Story:** As a developer, I want initial database migrations for users and user profiles, so that the application can store account and fitness information.

#### Acceptance Criteria

1. THE Database SHALL include a `users` migration with columns: `id`, `name`, `email` (unique), `password`, `email_verified_at` (nullable), `remember_token`, `created_at`, and `updated_at`.
2. THE Database SHALL include a `user_profiles` migration with columns: `id`, `user_id` (foreign key referencing `users.id`), `age` (nullable integer), `height` (nullable decimal with precision 5 and scale 2), `weight` (nullable decimal with precision 5 and scale 2), `gender` (nullable string), `fitness_goal` (nullable string), `fitness_level` (nullable string), `workout_preference` (nullable string), `availability` (nullable string), `created_at`, and `updated_at`.
3. WHEN `php artisan migrate` is executed against an empty Database, THE Migration files SHALL run without errors and create the `users` and `user_profiles` tables.
4. WHEN a User record is deleted, THE Database SHALL cascade the deletion to the associated User_Profile record via ON DELETE CASCADE on the `user_id` foreign key.
5. THE `user_profiles.user_id` column SHALL enforce a one-to-one relationship with the `users` table via a unique constraint.
6. WHEN `php artisan migrate:rollback` is executed, THE Migration files SHALL reverse the schema changes without errors.

### Requirement 6: Git Repository Setup

**User Story:** As a developer, I want both projects under version control with appropriate ignore rules, so that only source code and configuration templates are tracked.

#### Acceptance Criteria

1. THE Flutter_App SHALL be contained within a directory named `synchrofit_app` at the repository root.
2. THE Laravel_API SHALL be contained within a directory named `synchrofit_api` at the repository root.
3. THE repository root SHALL contain a top-level `.gitignore` that excludes OS-generated files (`.DS_Store`, `Thumbs.db`).
4. THE Flutter_App directory SHALL contain a `.gitignore` file at its root that excludes: `build/`, `.dart_tool/`, `.packages`, `*.iml`, and `.idea/`.
5. THE Laravel_API directory SHALL contain a `.gitignore` file at its root that excludes: `vendor/`, `node_modules/`, `.env`, `storage/*.key`, and `bootstrap/cache/*.php`.
6. THE Laravel_API SHALL include a tracked `.env.example` file that serves as the configuration template, while the `.env` file containing actual secrets remains excluded via `.gitignore`.

### Requirement 7: Project Documentation

**User Story:** As a developer, I want a README with setup instructions for both projects, so that any team member can run the full stack locally.

#### Acceptance Criteria

1. THE repository root SHALL contain a `README.md` file.
2. THE README.md SHALL document prerequisites including Flutter SDK 3.x+, PHP 8.2+, Composer, and MySQL 8.
3. THE README.md SHALL include step-by-step instructions for setting up and running the Flutter_App on an Android emulator, including at minimum: installing dependencies, launching an emulator, and running the app.
4. THE README.md SHALL include step-by-step instructions for setting up and running the Laravel_API locally, including at minimum: copying `.env.example` to `.env`, running `composer install`, generating the app key, creating the database, and starting the development server.
5. THE README.md SHALL document how to run database migrations using `php artisan migrate`.
6. THE README.md SHALL document the authentication approach (Sanctum) and include a brief explanation of why Sanctum was chosen over alternatives (e.g., lightweight, first-party Laravel package, designed for SPAs and mobile apps).
7. THE README.md SHALL note that Firebase Cloud Messaging and Laravel Reverb/WebSockets are planned for future iterations but are out of scope for this foundation.
