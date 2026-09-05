# SyncroFit Android Completion PRD

## Purpose

Deliver a production-ready, Android-only SyncroFit release by removing unsupported platform distribution, making every supported screen usable on Android phones and tablets, adding photo-based progress tracking, replacing the mock community feature with a real backend, and closing or explicitly retiring incomplete features discovered in the repository audit.

## Context and current state

The Flutter client currently contains Android, iOS, web, Windows, Linux, and macOS targets. The Android project is functional, but the repository and documentation still present this as a cross-platform mobile/web product. Community is routed in the app, yet `communityRepositoryProvider` uses `MockCommunityRepository`; Laravel has no community routes, models, migrations, or controllers. Progress is derived only from `workout_history` and has no progress-photo entity, media picker, device/cloud storage, or sharing capability.

## Goals

1. Ship and support Android only.
2. Eliminate overflow, clipping, keyboard-obscured controls, inaccessible actions, and unsafe fixed layouts at Android phone and tablet widths.
3. Let a signed-in user save, view, manage, compare, and share dated progress photos with an optional description.
4. Deliver a durable community API and connect the existing feed, detail, like, and comment UI to it.
5. Resolve the audited incomplete/unreachable functionality before release, either by implementing it or removing its route/UI/dead code.

## Non-goals

- iOS, web, Windows, Linux, and macOS delivery or regression support.
- Social direct messages, following, groups, or a real-time chat system.
- AI body-composition analysis from progress photos.
- A trainer/consultation backend unless separately prioritized.

## Personas

- **Member:** records workouts, tracks visual progress privately, and participates in the community.
- **Moderator/admin:** needs traceable author ownership and the ability to moderate community content (admin surface may follow the first release, but the data model must support it).

## Requirements

### 1. Android-only product and delivery

- Set Android as the sole supported runtime in README, onboarding/developer instructions, CI, release scripts, and QA plans.
- Remove unsupported platform directories (`ios/`, `web/`, `windows/`, `linux/`, `macos/`) from version control after confirming no repository automation requires them. Remove web-only dependencies/configuration, including `sqflite_common_ffi_web`, if no longer needed.
- Keep `android/`, Android icon configuration, and Android build configuration; use Android application IDs, versioning, signing, and release artifacts as the source of truth.
- Configure Android permissions only as needed by the implementation: network access, camera/media capture, and Android-version-appropriate media-read access. Explain permissions at the point of use and handle denial without blocking the rest of the app.
- Update local-development guidance to use an Android emulator or physical device; no Chrome run command remains.

**Acceptance criteria**

- `flutter build appbundle --release` completes in CI and generates the versioned Android artifact.
- CI runs Flutter analysis/tests and Android build only; no unsupported platform job remains.
- A fresh Android install can register, log in, use all released tabs, select/capture a photo, and share a photo without a platform-specific exception.

### 2. Android responsive-layout remediation

Treat Android phones from 320 dp to 600 dp wide and tablets/foldables from 600 dp to 1,280 dp wide as supported. Validate portrait and landscape, 200% system font scale, display cutouts, gesture navigation, and keyboard-open states.

- Create a small responsive layout standard: width breakpoints, maximum readable content width, minimum tap target of 48 dp, common horizontal padding, and a reusable adaptive grid/list helper. Avoid per-screen ad hoc breakpoints.
- Use `SafeArea`, scrollable forms, `resizeToAvoidBottomInset`/keyboard insets, `Flexible`/wrapping text, and constrained content widths where appropriate. No text, buttons, charts, bottom navigation, or dialogs may clip or overflow.
- Make stat cards and dashboard/progress charts adapt from two columns to one column when the available width cannot support two readable cards. Chart labels must remain legible or be simplified at narrow widths.
- Ensure long user-generated names/descriptions and translated-length strings wrap or ellipsize intentionally in community cards, workout rows, settings, profiles, and consultation rows.
- Verify dialogs and workout-generator sheets are height-safe, scrollable, and usable with the keyboard visible.
- Add widget/golden tests at compact phone, standard phone, tablet, and large font-size configurations for the high-traffic screens: authentication, dashboard, workout generator/active workout, exercise library/detail, progress, community, profile edit, and settings.

**Acceptance criteria**

- Flutter tests include the viewports above and fail on `RenderFlex overflow` or uncaught layout exceptions.
- Manual Android QA finds no blocked primary action at the defined widths/orientations/font scale.
- Every interactive icon/button has a semantic label and at least a 48 dp hit target.

### 3. Progress photos

#### Member experience

- Add a **Photos** section to Progress, with an empty state and an accessible “Add progress photo” action.
- A member can capture with the camera or select one existing image, preview it, enter an optional description (max 500 characters), choose the capture/upload date (default: today in the member’s locale), and save.
- Store the original image privately. Create a bounded display derivative/thumbnail; enforce supported image type, size, dimensions, and upload timeout before transmitting. Show upload and retry states.
- Show records newest first as a responsive timeline/grid. Each record displays image, description when present, and the selected date. Full-screen viewing must allow deletion from the member’s own record with confirmation.
- Support side-by-side comparison of exactly two selected photos, preserving their dates and descriptions.
- Support Android system sharing of a rendered image or share card that includes the photo, optional description, and uploaded/capture date. Sharing is always an explicit action; never make a private photo public automatically.
- Deleting a record deletes its owned media and derived thumbnails. Retain no orphaned storage objects.

#### API and data

- Add `progress_photos`: UUID/id, `user_id`, private original path, thumbnail path, `description` nullable, `captured_on` date, timestamps, soft-delete/moderation-ready fields if adopted. Index `(user_id, captured_on)`.
- Add authenticated endpoints: `GET /api/progress-photos` (cursor pagination), `POST /api/progress-photos` (multipart), `GET /api/progress-photos/{id}`, and `DELETE /api/progress-photos/{id}`. Return only records belonging to the authenticated user; return 404 rather than exposing another user’s record.
- Use Laravel storage abstraction with a private disk; serve images through authorized endpoints or time-limited URLs. Do not expose predictable public paths.
- Add a Flutter `ProgressPhoto` model, remote repository, local pending-upload representation, and sync-queue handling so a record created offline has a visible pending state and resumes safely when connected.

**Acceptance criteria**

- Valid JPG/PNG/HEIC input can be selected/captured, saved, survives app restart, and appears with its user-selected date and description.
- Invalid/oversized input produces an actionable error and no database record/media object.
- Users cannot list, retrieve, or delete another user’s photo.
- Offline create/retry and deletion are covered by automated tests.

### 4. Community backend

#### Release scope

- Replace `MockCommunityRepository` in production provider wiring with a remote repository backed by Laravel. Mock implementations may remain test fixtures only.
- Support chronological cursor-paginated feed, post detail, create text post, like/unlike, and add comments—the behaviors the routed UI already represents.
- Add a visible post-composer entry point in the feed. A post body is required after trimming; limit to 2,000 characters. Comments are required after trimming and limited to 1,000 characters.
- Show server-authoritative counts and whether the authenticated member liked a post. Optimistic UI may be used, but it must roll back and surface an error when the request fails.
- Preserve author identity using `user_id`; API responses expose safe display data, never email or private profile fields.

#### Backend contract

- Migrations/models: `posts` (`user_id`, `body`, timestamps, optional soft delete); `comments` (`post_id`, `user_id`, `body`, timestamps, optional soft delete); `post_likes` (`post_id`, `user_id`, timestamps, unique composite key). Add foreign keys and feed indexes.
- Endpoints: `GET /api/community/posts`, `POST /api/community/posts`, `GET /api/community/posts/{post}`, `PUT /api/community/posts/{post}/like` (idempotent like), `DELETE /api/community/posts/{post}/like` (idempotent unlike), and `POST /api/community/posts/{post}/comments`.
- Enforce policies for ownership/moderation and request validation/rate limiting for creation, comments, and likes. Return the existing standard API envelope.
- Add resource transformers so Flutter receives stable fields: post id, author id/display name, body, created timestamp, like count, viewer-liked flag, comment count, and paged comments on detail.

**Acceptance criteria**

- Two independently authenticated users see the same persisted posts/comments and correct per-user like state after refresh/restart.
- Duplicate likes never inflate count; concurrent operations remain consistent.
- Unauthorized requests return 401; cross-user edit/delete attempts return 403/404 as policy dictates.
- Laravel feature tests cover validation, pagination, like idempotency, ownership, and JSON contract; Flutter tests cover loading, empty, error, success, and optimistic rollback states.

### 5. Audited incomplete and unused work

The following items were confirmed by source inspection and must be resolved as part of this release planning:

| Finding | Evidence | Required disposition |
| --- | --- | --- |
| Change Password is exposed in Settings but always fails | `RemoteAuthRepository.changePassword` returns 501; no API route/controller exists | Implement authenticated `PUT /api/user/password` with current-password validation, password rules, token/session handling, tests, and client integration. |
| Notifications route is a dead “removed” screen | `/notifications` renders “Notifications have been removed”; `NotificationItem` mock data is otherwise unused | Remove the route/constants/models/mock data and dashboard entry point, or implement a real inbox. For this release, remove the dead route and retain only clearly labeled local notification preferences until push delivery is separately funded. |
| Notification backend is internally inconsistent | `NotificationService` references `DeviceToken`, while the schema simplification migration drops `device_tokens`; no model/routes/token registration exist | Do not ship this service as functional. Remove/archive it with dead notification code, or fully restore the token schema/model, Android FCM integration, API, and delivery jobs in a separate notification epic. |
| Search screen is placeholder and unreachable | `SearchScreen` only shows “Search”; no router entry references it | Remove it now, or add a scoped search feature with route, UI, and backend/client search contract. Default release disposition: remove. |
| Consultation/trainer experience is mock-only | `consultationRepositoryProvider` uses `MockConsultationRepository`; Laravel has no consultation API | Hide/remove trainer routes and settings entry for this release, or fund it as its own backend epic. Do not present mock appointments as production data. |
| Exercise video is presented as a placeholder | active workout says “Video guide coming soon”; exercise detail falls back to placeholder | Keep the section only when a playable Android-supported video URL exists; otherwise replace with a neutral “No video available” state. A true player is a separate scope item. |
| Progress provider uses a dummy user id | `ProgressNotifier` calls history with `const userId = ''` | Derive user identity from authenticated state or remove the unused parameter; add an auth-bound progress test. |
| Platform scope and docs conflict | README claims mobile/web and includes Chrome command; non-Android folders remain | Correct as part of Android-only work above. |

## Delivery order

1. Establish Android-only build/CI baseline and responsive design test harness.
2. Fix responsive defects on existing released screens; complete or remove all audited dead/mock functionality.
3. Implement progress-photo storage/API/client/offline flow and share action.
4. Implement community migrations/API/client replacement, then launch behind moderation/rate-limit controls.
5. Run release QA, security/access-control tests, Android device matrix, migration rollback/backup validation, and production readiness review.

## Dependencies and risks

- Progress images require an approved private object-storage provider, retention/deletion policy, maximum upload specification, and Android privacy-policy update before launch.
- Community requires moderation ownership, reporting/escalation policy, terms of use, abuse/rate-limit thresholds, and operational monitoring. A report endpoint is strongly recommended before public launch, even if its moderation console follows.
- Removing Flutter platform directories changes contributor workflows and should be performed in a dedicated reviewed change after Android CI is green.
- Current migration history creates/drops legacy tables; test the upgrade path against a production-like database before adding community and media migrations.

## Success metrics

- 100% of release-blocking layout test matrix passes and zero known Android layout blockers at launch.
- At least 95% of valid progress-photo uploads complete successfully; failed uploads are recoverable without data loss.
- Community persistence, like/comment contract, and authorization feature tests pass in CI.
- Zero production calls to mock community/consultation repositories or intentionally removed routes.
- Android release build and full Flutter/Laravel test suites pass from a clean checkout.
