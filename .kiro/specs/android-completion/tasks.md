# Implementation Plan: SyncroFit Android Completion

## Overview

This plan delivers the Android-only SyncroFit release defined in `PRD.md`. Work proceeds from release decisions and an Android build baseline through unsupported-platform cleanup, responsive remediation, incomplete-feature disposition, progress photos, the community backend, and final production-readiness validation. Tasks reference PRD sections directly because this release is governed by the root PRD rather than a separate requirements document.

## Tasks

- [ ] 1. Release decisions, repository audit, and baseline
  - [ ] 1.1 Lock Android and release-support decisions
    - Record the minimum and target Android API levels, supported ABIs, phone/tablet/foldable scope, production application ID, versioning scheme, and release artifact naming
    - Confirm signing-key ownership and ensure signing secrets are supplied through protected CI/environment configuration rather than committed files
    - Define the physical-device and emulator QA matrix across supported API levels, widths, orientations, cutouts, gesture navigation, and 200% font scale
    - Define progress-photo upload limits: accepted MIME types, maximum bytes and dimensions, thumbnail dimensions/format, timeout, retry limit, per-user quota, EXIF handling, and signed-URL lifetime
    - Select and approve the private object-storage provider, retention/deletion policy, backup-retention behavior, and Android privacy-policy changes
    - Assign community moderation ownership, abuse escalation, rate-limit thresholds, reporting approach, and whether launch is public or a controlled beta
    - _PRD: Goals 1–5; §1 acceptance criteria; Dependencies and risks_

  - [ ] 1.2 Audit platform, automation, dependency, and route usage
    - Identify all references to `ios/`, `web/`, `windows/`, `linux/`, `macos/`, Chrome, desktop builds, and unsupported release artifacts in source, scripts, documentation, CI, and tooling
    - Audit `pubspec.yaml`, generated plugin registrants, and Android Gradle configuration for web/desktop-only packages and native Android plugins that require the NDK or CMake
    - Confirm no repository automation depends on unsupported platform directories before deleting them
    - Inventory all production provider bindings to mocks, all routed screens/tabs, and all dead or unreachable route constants
    - Capture the current Android build, Flutter analysis/test, and Laravel test results as the remediation baseline
    - _PRD: Context and current state; §1; §5_

  - [ ] 1.3 Establish clean-checkout Android build baseline
    - Restore dependencies from a clean checkout using documented Flutter, Android SDK, JDK, PHP, Composer, and database versions
    - Run Flutter analysis/tests, Laravel tests, and `flutter build appbundle --release`
    - Record existing failures separately from failures introduced by this plan
    - Confirm the generated Android App Bundle location and current version metadata
    - _PRD: §1 acceptance criteria; Success metrics_

- [ ] 2. Android-only project and delivery configuration
  - [ ] 2.1 Remove unsupported Flutter platforms and dependencies
    - Remove `ios/`, `web/`, `windows/`, `linux/`, and `macos/` from version control after the audit confirms they are unused
    - Remove web-only or desktop-only dependencies and configuration, including `sqflite_common_ffi_web`, when no Android runtime path requires them
    - Remove unsupported platform assets, scripts, conditional imports, generated configuration, and obsolete ignore rules
    - Regenerate Flutter dependency metadata and verify Android plugin registration remains valid
    - Preserve Android NDK/CMake configuration only when an audited Android native dependency requires it
    - _PRD: §1 Android-only product and delivery_

  - [ ] 2.2 Update Android manifests and runtime permission handling
    - Keep only permissions required for network access, camera capture, and Android-version-appropriate media selection
    - Prefer Android Photo Picker where available instead of broad storage/media-library permissions
    - Configure camera capture output safely through Android-supported content URIs/FileProvider behavior where required
    - Add point-of-use permission explanations, denial handling, retry, and settings guidance without blocking unrelated app functionality
    - Verify manifest merging does not introduce unnecessary permissions through dependencies
    - _PRD: §1 Android permissions; §3 member experience_

  - [ ] 2.3 Make documentation and developer workflows Android-only
    - Update README, onboarding, local-development instructions, QA guidance, and release procedures to state that Android is the only supported runtime
    - Remove Chrome, iOS, web, and desktop run/build instructions
    - Document Android emulator and physical-device setup and the exact supported build commands
    - Document any required Android NDK/CMake setup only if task 1.2 confirms a native dependency needs it
    - _PRD: §1 Android-only product and delivery; §5 platform scope and docs conflict_

  - [ ] 2.4 Restrict CI and release automation to Android
    - Remove unsupported platform jobs and caches from CI
    - Run Flutter formatting checks, analysis, tests, and the Android release App Bundle build
    - Run Laravel setup, migrations, and test suites in the applicable backend job
    - Inject signing credentials securely, generate a versioned `.aab`, and publish it as a CI artifact
    - Fail CI when required Android or backend validation fails
    - _PRD: §1 acceptance criteria; Success metrics_

- [ ] 3. Responsive-layout foundation
  - [ ] 3.1 Define reusable Android responsive standards
    - Define compact, standard, tablet, and large-width breakpoints covering 320–1,280 dp
    - Define maximum readable content width, common horizontal padding, spacing rules, and the 48 dp minimum tap target
    - Create reusable constrained-page, adaptive grid/list, and responsive card helpers instead of per-screen breakpoints
    - Define chart-label simplification and one-column fallback behavior for narrow widths
    - Document intentional wrapping and ellipsis rules for user-generated and translated-length text
    - _PRD: §2 Android responsive-layout remediation_

  - [ ] 3.2 Add reusable safe form, dialog, and keyboard patterns
    - Add shared patterns for `SafeArea`, scrollable forms, keyboard insets, focus traversal, and bottom-action visibility
    - Ensure dialogs and bottom sheets constrain their height and remain scrollable with the keyboard visible
    - Add reusable semantic-label and minimum-hit-target wrappers where stock widgets do not satisfy accessibility requirements
    - _PRD: §2 responsive requirements and acceptance criteria_

  - [ ] 3.3 Create the responsive test harness
    - Define compact phone, standard phone, tablet, landscape, and 200% text-scale test configurations
    - Add helpers that surface `RenderFlex overflow`, clipping, and uncaught layout exceptions as test failures
    - Establish deterministic golden-test fonts, themes, and image/network stubs where golden tests are used
    - _PRD: §2 acceptance criteria_

- [ ] 4. Remediate existing Android screens
  - [ ] 4.1 Remediate authentication and dashboard
    - Make registration and login forms scrollable, keyboard-safe, cutout-safe, and usable at 320 dp and 200% text scale
    - Adapt dashboard stat cards and charts from two columns to one when content cannot remain readable
    - Constrain tablet content width and preserve intentional empty/loading/error states
    - Ensure dashboard navigation exposes no removed or unreachable feature
    - _PRD: §2 high-traffic screens; §5 audited work_

  - [ ] 4.2 Remediate workout generation and active-workout flows
    - Make workout-generator dialogs/sheets height-safe and keyboard-safe
    - Prevent exercise names, timers, controls, set/repetition values, and primary actions from clipping in portrait or landscape
    - Preserve active-workout controls above gesture-navigation and system insets
    - Verify long generated workout content scrolls without obscuring completion actions
    - _PRD: §2 high-traffic screens_

  - [ ] 4.3 Remediate exercise library and exercise detail
    - Adapt filter/search controls, lists/grids, exercise cards, and detail content across phone and tablet widths
    - Ensure long names/instructions wrap or ellipsize intentionally
    - Keep media areas aspect-ratio safe and show a stable fallback when no playable video exists
    - _PRD: §2; §5 exercise video disposition_

  - [ ] 4.4 Remediate progress and community screens
    - Make progress cards, statistics, charts, feed cards, post detail, comment forms, and loading/error/empty states adaptive
    - Simplify chart labels or layout at narrow widths and constrain content on tablets
    - Handle long member names, post bodies, comments, and descriptions without overflow
    - Reserve responsive integration points for progress-photo grids and the post composer
    - _PRD: §2 high-traffic screens; §3; §4_

  - [ ] 4.5 Remediate profile, profile edit, settings, and remaining released tabs
    - Make profile and settings rows safe for long and translated labels
    - Keep profile-edit fields and save actions accessible while the keyboard is visible
    - Audit every released tab, dialog, snackbar, and bottom sheet for safe areas, clipping, scrolling, and tablet constraints
    - Ensure bottom navigation remains usable with large text and gesture navigation
    - _PRD: §2 high-traffic screens and acceptance criteria_

  - [ ] 4.6 Complete accessibility remediation
    - Give every interactive icon and button a meaningful semantic label
    - Enforce at least a 48 dp hit target for every interactive control
    - Verify logical focus order, screen-reader announcements for loading/errors, and accessible labels for charts and images
    - Verify text remains understandable at 200% system font scale without hiding primary actions
    - _PRD: §2 acceptance criteria_

- [ ] 5. Resolve audited incomplete and unused functionality
  - [ ] 5.1 Implement the authenticated change-password backend
    - Add `PUT /api/user/password` under authenticated middleware
    - Validate the current password, enforce configured password/confirmation rules, and return the standard API envelope
    - Define token/session behavior after a successful password change and avoid logging password values
    - Add Laravel feature tests for success, incorrect current password, validation failures, unauthenticated access, and token/session behavior
    - _PRD: §5 Change Password finding_

  - [ ] 5.2 Connect and validate the Flutter change-password flow
    - Replace the `RemoteAuthRepository.changePassword` 501 behavior with the authenticated API request
    - Provide inline validation, loading, success, and actionable error states
    - Make the form responsive and keyboard-safe
    - Add Flutter repository/state/widget coverage for success and failure paths
    - _PRD: §5 Change Password finding; §2_

  - [ ] 5.3 Remove the dead notification inbox and inconsistent notification backend
    - Remove `/notifications`, route constants, removed-screen UI, `NotificationItem` mock data, and dashboard entry points
    - Retain only clearly labeled local notification preferences that have real behavior
    - Remove or archive `NotificationService` and `DeviceToken` references that cannot work with the simplified schema
    - Verify no production code, routes, jobs, or providers claim push delivery is functional
    - _PRD: §5 Notifications findings_

  - [ ] 5.4 Remove placeholder search functionality
    - Delete the unreachable placeholder `SearchScreen` and unused imports/assets
    - Verify no route, navigation action, provider, or documentation references the removed feature
    - _PRD: §5 Search screen finding_

  - [ ] 5.5 Remove mock-only consultation/trainer functionality from production
    - Hide or remove trainer and consultation routes, navigation actions, settings entries, and mock appointment presentation
    - Restrict mock consultation repositories to tests or delete them when unused
    - Verify no production provider resolves to `MockConsultationRepository`
    - _PRD: Non-goals; §5 Consultation/trainer finding; Success metrics_

  - [ ] 5.6 Replace exercise-video placeholders with truthful states
    - Show playable media only when an Android-supported video URL or asset exists
    - Replace “Video guide coming soon” and misleading placeholders with a neutral “No video available” state
    - Handle invalid or unavailable media without blocking the exercise detail or active workout
    - _PRD: §5 Exercise video finding_

  - [ ] 5.7 Bind progress history to authenticated identity
    - Remove the dummy empty user ID from `ProgressNotifier`
    - Derive identity from authenticated state or remove the repository parameter when the backend already scopes requests to the authenticated user
    - Clear or switch user-scoped progress state safely during logout/account changes
    - Add an auth-bound progress test
    - _PRD: §5 Progress provider finding_

- [ ] 6. Checkpoint — Android baseline and existing functionality
  - Run formatting, Flutter analysis/tests, Laravel tests, and `flutter build appbundle --release`
  - Verify unsupported platform directories/jobs are gone, every released route is real, and no removed feature remains reachable
  - Complete manual responsive smoke testing before beginning media and community implementation

- [ ] 7. Progress-photo backend and private media storage
  - [ ] 7.1 Create the progress-photo schema and model
    - Add a `progress_photos` migration with UUID/id, `user_id`, private original path, thumbnail path, nullable description, `captured_on`, timestamps, and the adopted deletion/moderation fields
    - Add the `(user_id, captured_on)` index, foreign key behavior, casts, fillable fields, and user relationship
    - Ensure identifiers and API serialization use one stable type consistently
    - Implement a reversible migration and test it against the supported database engine
    - _PRD: §3 API and data_

  - [ ] 7.2 Configure private media storage and image processing
    - Configure Laravel storage abstraction for the approved private disk
    - Validate MIME by file content, extension, bytes, dimensions, and supported JPG/PNG/HEIC decoding before creating a record
    - Strip disallowed EXIF metadata, normalize orientation, and create bounded display/thumbnail derivatives
    - Apply the approved timeout and per-user quota and clean partial files after processing failures
    - Never expose predictable public storage paths
    - _PRD: §3 member experience and API/data; Dependencies and risks_

  - [ ] 7.3 Implement authorized progress-photo API endpoints
    - Add authenticated cursor-paginated `GET /api/progress-photos`
    - Add multipart `POST /api/progress-photos` with description, locale-safe `captured_on`, and an idempotency/client-operation key for safe retries
    - Add `GET /api/progress-photos/{id}` and `DELETE /api/progress-photos/{id}`
    - Return only authenticated-user records and use 404 for another user’s record
    - Serve originals/thumbnails through authorized responses or short-lived URLs and the standard API envelope
    - Define stable cursor fields, page-size defaults/limits, ordering by `captured_on DESC, id DESC`, and error codes
    - _PRD: §3 API and data; acceptance criteria_

  - [ ] 7.4 Implement media lifecycle and deletion guarantees
    - Delete owned originals and derivatives when a progress-photo record is deleted according to the adopted retention policy
    - Handle storage/database failure ordering so retries do not leave orphaned media or inaccessible records
    - Add a reconciliation mechanism or operational command to detect and remove orphaned storage objects safely
    - Apply account-deletion and backup-retention policy to progress media
    - _PRD: §3 deletion requirements; Dependencies and risks_

  - [ ] 7.5 Add progress-photo backend tests
    - Test valid JPG, PNG, and supported HEIC upload, metadata persistence, thumbnail generation, pagination, retrieval, and deletion
    - Test authentication, cross-user isolation, expired URLs, invalid MIME, oversized/dimension-invalid input, malformed dates, quota, timeout/failure cleanup, and idempotent retry
    - Test that invalid uploads create neither a database record nor retained media and that deletion leaves no orphaned owned objects
    - _PRD: §3 acceptance criteria_

- [ ] 8. Flutter progress-photo data and offline synchronization
  - [ ] 8.1 Add Android media/share dependencies and domain models
    - Select actively maintained Android-capable packages for camera/photo selection, image handling, temporary files, and system sharing
    - Add only the required packages with versions consistent with repository dependency policy
    - Create `ProgressPhoto`, pagination, upload state, and failure models with stable JSON/date serialization
    - Keep private media URLs/tokens out of logs and persisted diagnostics
    - _PRD: §3 member experience and API/data_

  - [ ] 8.2 Implement the remote progress-photo repository
    - Implement cursor-paginated list, multipart create, authorized detail/media retrieval, and delete operations
    - Enforce client-side type/size/dimension checks where possible while treating server validation as authoritative
    - Surface upload progress, timeout, retryable errors, permanent validation errors, and expired-media-URL refresh
    - _PRD: §3 API and data_

  - [ ] 8.3 Add local pending-upload persistence
    - Extend the local schema/DAO layer with user-scoped pending progress-photo records and durable references to app-owned image copies
    - Persist description, captured date, client operation ID, queue state, retry count, failure reason, and created timestamp
    - Ensure pending records survive app restart and are cleared safely on logout without leaking one user’s media to another
    - Handle missing/corrupt local files with an actionable permanent-failure state
    - _PRD: §3 offline requirements and acceptance criteria_

  - [ ] 8.4 Extend synchronization for progress-photo operations
    - Queue offline creates and adopted offline deletions in deterministic order
    - Resume uploads when authenticated connectivity returns and use idempotency keys to prevent duplicate records
    - Apply bounded retry/backoff for transient failures and preserve permanent failures for user action
    - Reconcile local pending IDs with server IDs and refresh the remote list after successful synchronization
    - Define behavior for logout, remote deletion, and local/remote conflicts
    - _PRD: §3 local pending-upload representation and sync queue_

  - [ ] 8.5 Wire authenticated progress-photo providers and state
    - Add Riverpod providers/notifiers for paging, pending items, selection, upload progress, retry, deletion, comparison, and media URL refresh
    - Merge pending and synchronized records without duplicates in newest-first order
    - Reset all user-scoped state on logout/account switch
    - _PRD: §3 member experience and API/data_

- [ ] 9. Progress-photo Android experience
  - [ ] 9.1 Add the Photos section and capture/select flow
    - Add a Photos section to Progress with an empty state and accessible “Add progress photo” action
    - Offer camera capture or one-image selection using Android-appropriate APIs
    - Preview the image, accept an optional description limited to 500 characters, and select a date defaulted to today in the member’s locale
    - Explain permissions at point of use and handle denial, cancellation, invalid input, and upload failure without blocking Progress
    - Show save/upload progress, offline pending status, retry, and permanent-failure actions
    - _PRD: §3 Member experience_

  - [ ] 9.2 Build the responsive photo timeline/grid
    - Display synchronized and pending records newest first with image/thumbnail, selected date, and optional description
    - Adapt between compact timeline/list and tablet grid using shared responsive helpers
    - Add cursor pagination, pull-to-refresh, loading, empty, partial-data, and error states
    - Preserve accessibility labels while avoiding disclosure of private descriptions in unintended semantics
    - _PRD: §3 Member experience; §2_

  - [ ] 9.3 Implement full-screen viewing and deletion
    - Open an authorized full-screen image view with date and optional description
    - Allow deletion only for the member’s own record and require confirmation
    - Show deletion progress/failure and remove the item only according to the chosen optimistic/confirmed behavior
    - Refresh expired media access without exposing a public path
    - _PRD: §3 Member experience and API/data_

  - [ ] 9.4 Implement exactly-two-photo comparison
    - Allow selection of exactly two available photos and clearly communicate selection count
    - Render a responsive side-by-side comparison preserving each date and description
    - Handle mixed orientation/aspect ratios, unavailable pending media, compact screens, tablets, and landscape
    - _PRD: §3 Member experience_

  - [ ] 9.5 Implement explicit Android system sharing
    - Render a temporary share image/card containing the chosen photo, selected date, and optional description
    - Invoke Android system sharing only after an explicit user action
    - Avoid changing the photo’s private/public status and clean temporary share files after use according to platform constraints
    - Handle missing share targets and share-generation failures accessibly
    - _PRD: §3 Member experience and acceptance criteria_

  - [ ] 9.6 Add progress-photo Flutter tests
    - Cover model serialization, repository mapping, paging, pending merge, idempotent offline retry, restart recovery, deletion, logout isolation, and permanent-failure handling
    - Add widget tests for empty, loading, error, upload, pending, timeline/grid, full-screen, comparison, and share states
    - Exercise compact phone, tablet, landscape, and 200% text-scale configurations without overflow
    - _PRD: §3 acceptance criteria; §2 acceptance criteria_

- [ ] 10. Checkpoint — Progress photos complete
  - Run progress-photo backend and Flutter tests, full Flutter analysis/tests, Laravel tests, and an Android release build
  - On a physical Android device, verify camera capture, Photo Picker selection, offline pending persistence, reconnect retry, restart survival, authorized viewing, comparison, deletion, and system sharing
  - Verify cross-user access is denied and no invalid upload or deletion leaves an orphaned object

- [ ] 11. Community backend
  - [ ] 11.1 Create community schema and models
    - Add `posts`, `comments`, and `post_likes` migrations with foreign keys, timestamps, adopted soft-delete/moderation fields, feed/comment indexes, and a unique `(post_id, user_id)` like constraint
    - Add Laravel models, casts, fillable fields, and user/post/comment/like relationships
    - Implement reversible migrations and define parent deletion behavior
    - _PRD: §4 Backend contract_

  - [ ] 11.2 Add policies, validation, resources, and pagination contract
    - Add policies for ownership and moderation while exposing only safe author display fields
    - Validate trimmed post bodies as required and at most 2,000 characters
    - Validate trimmed comments as required and at most 1,000 characters
    - Add stable API resources for post id, author id/display name, body, created timestamp, like count, viewer-liked flag, comment count, and detail comments
    - Define newest-first cursor ordering, stable tie-breaking, default/maximum page sizes, comment paging, and the standard API envelope
    - _PRD: §4 Release scope and Backend contract_

  - [ ] 11.3 Implement feed, create-post, and post-detail endpoints
    - Implement `GET /api/community/posts` with chronological newest-first cursor pagination
    - Implement `POST /api/community/posts`
    - Implement `GET /api/community/posts/{post}` with independently paged comments or a clearly defined first comments page and cursor
    - Scope all endpoints to authenticated users and avoid exposing email/private profile fields
    - _PRD: §4 Release scope and Backend contract_

  - [ ] 11.4 Implement idempotent like and unlike endpoints
    - Implement `PUT /api/community/posts/{post}/like` as an idempotent like operation
    - Implement `DELETE /api/community/posts/{post}/like` as an idempotent unlike operation
    - Use the unique database constraint and transaction-safe count computation so duplicate/concurrent requests cannot inflate counts
    - Return server-authoritative counts and viewer-liked state
    - _PRD: §4 Release scope, Backend contract, and acceptance criteria_

  - [ ] 11.5 Implement comment creation
    - Implement `POST /api/community/posts/{post}/comments`
    - Return the created comment resource and updated server-authoritative comment count
    - Enforce post visibility/moderation policy and handle deleted or unavailable posts consistently
    - _PRD: §4 Release scope and Backend contract_

  - [ ] 11.6 Add abuse controls and operational moderation readiness
    - Apply separate configurable rate limits to post creation, comments, and likes
    - Implement the approved minimum report/escalation mechanism before public launch, or enforce the controlled-beta release decision from task 1.1
    - Provide an operator mechanism to remove/moderate content and retain a traceable audit trail
    - Add monitoring for elevated errors, rate-limit events, and abuse signals without logging private profile fields
    - _PRD: Personas; §4 Backend contract; Dependencies and risks_

  - [ ] 11.7 Add Laravel community feature tests
    - Cover authentication, validation, safe author fields, newest-first pagination, cursor stability, post detail, comments, rate limiting, and JSON contract
    - Cover per-user like state, duplicate/idempotent likes and unlikes, and concurrent operations
    - Cover ownership/moderation behavior and 403/404 handling only for operations actually exposed by the release contract
    - Verify two authenticated users see shared persisted content with distinct viewer-liked state
    - _PRD: §4 acceptance criteria_

- [ ] 12. Flutter community integration
  - [ ] 12.1 Define community models and remote repository
    - Align post/comment/page models with the stable backend resources and date/cursor serialization
    - Implement feed paging, create post, detail, paged comments, like, unlike, and add-comment operations
    - Map authentication, validation, rate-limit, network, and server errors to actionable domain failures
    - _PRD: §4 Release scope and Backend contract_

  - [ ] 12.2 Replace production mock-provider wiring
    - Bind `communityRepositoryProvider` to the Laravel-backed remote repository in production
    - Keep `MockCommunityRepository` only in explicit test overrides or remove it when unnecessary
    - Verify no production path imports or resolves the mock implementation
    - _PRD: §4 Release scope; Success metrics_

  - [ ] 12.3 Connect the feed and post composer
    - Load the cursor-paginated newest-first feed with refresh, loading, empty, partial-data, and retry states
    - Add a visible and accessible post-composer entry point
    - Enforce trimmed required content and the 2,000-character limit while keeping the keyboard-visible submit action usable
    - Insert the confirmed server response without duplicating it during refresh/pagination
    - _PRD: §4 Release scope; §2_

  - [ ] 12.4 Connect post detail and comments
    - Load post detail and paged comments from the backend
    - Enforce trimmed required comments and the 1,000-character limit
    - Submit comments with loading/error handling and update server-authoritative counts
    - Handle deleted/moderated/unavailable posts without leaving an unusable screen
    - _PRD: §4 Release scope_

  - [ ] 12.5 Implement optimistic like/unlike with rollback
    - Update viewer-liked state and count optimistically while preventing repeated-tap races
    - Reconcile with the server-authoritative response
    - Roll back state and surface an accessible error when a request fails
    - Preserve correct per-user state across refresh, restart, logout, and account switch
    - _PRD: §4 Release scope and acceptance criteria_

  - [ ] 12.6 Add Flutter community tests
    - Cover model/repository mapping, cursor paging, loading, empty, error, success, refresh, and account isolation
    - Cover composer and comment validation boundaries
    - Cover optimistic like/unlike success, rapid taps, server reconciliation, and rollback
    - Add responsive widget tests for feed, composer, detail, and comments at required Android viewports and 200% text scale
    - _PRD: §4 acceptance criteria; §2 acceptance criteria_

- [ ] 13. Cross-feature quality and security validation
  - [ ] 13.1 Complete required responsive widget/golden coverage
    - Cover authentication, dashboard, workout generator, active workout, exercise library/detail, progress, community, profile edit, and settings
    - Run compact phone, standard phone, tablet, landscape, and 200% text-scale configurations
    - Fail on `RenderFlex overflow`, uncaught layout exceptions, inaccessible primary actions, or golden differences outside approved updates
    - _PRD: §2 acceptance criteria_

  - [ ] 13.2 Complete accessibility validation
    - Test semantic labels and 48 dp hit targets for every interactive icon/button on released screens
    - Verify focus order, screen-reader announcements, large-text behavior, contrast, and keyboard-visible actions
    - Conduct manual TalkBack smoke testing for authentication, progress-photo creation/sharing, community posting/commenting, and settings
    - _PRD: §2 acceptance criteria_

  - [ ] 13.3 Complete authorization and privacy validation
    - Test that users cannot list, retrieve, delete, or receive signed URLs for another user’s progress photos
    - Test that community responses never expose email or private profile fields
    - Verify media paths, tokens, descriptions, passwords, and sensitive request bodies are absent from logs and analytics
    - Verify logout/account switching clears user-scoped caches, pending UI state, and authorized media access
    - _PRD: §3 and §4 acceptance criteria; Dependencies and risks_

  - [ ] 13.4 Complete offline and failure-mode validation
    - Test restart, connectivity loss, timeout, duplicate retry, partial upload, missing local media, expired media URL, and backend recovery
    - Verify progress-photo mutations recover without duplication or data loss
    - Verify community failures leave coherent UI state and optimistic likes roll back
    - _PRD: §3 and §4 acceptance criteria; Success metrics_

- [ ] 14. Migration and production-readiness validation
  - [ ] 14.1 Validate database upgrades, rollback, and backups
    - Apply all migrations to a production-like copy that includes the repository’s legacy create/drop history
    - Verify existing users, workouts, and history remain intact
    - Exercise supported rollback/recovery procedures and validate backup restoration
    - Document expected migration duration, locks, and deployment order
    - _PRD: Delivery order; Dependencies and risks_

  - [ ] 14.2 Configure observability and release metrics
    - Add privacy-safe monitoring for upload attempts, valid-upload success/failure/retry, orphan cleanup, community API errors, rate limits, and moderation events
    - Define the measurement interval and denominator for the 95% valid progress-photo upload success target
    - Add alerts and operational ownership for sustained upload failures, storage errors, authorization anomalies, and community abuse signals
    - _PRD: Dependencies and risks; Success metrics_

  - [ ] 14.3 Execute the Android manual QA matrix
    - Test fresh install, registration, login, every released tab, camera selection/capture, progress-photo save/restart/compare/delete/share, community post/like/comment, profile, password change, and settings
    - Test widths from 320–1,280 dp, portrait/landscape, 200% font scale, cutouts, gesture navigation, keyboard-open states, permission denial, offline/reconnect, and supported Android API levels
    - Confirm no unsupported-platform exception, clipped primary action, dead route, mock production data, or misleading unavailable feature remains
    - _PRD: §1 and §2 acceptance criteria; Delivery order_

  - [ ] 14.4 Execute clean-checkout release validation
    - From a clean checkout, install exact dependencies, configure environment through documented secure steps, migrate the database, and run all suites
    - Run formatting checks, Flutter analysis/tests, Laravel tests, and security/access-control tests
    - Run `flutter build appbundle --release` and verify the versioned signed Android artifact
    - Confirm CI contains no unsupported platform job and production provider wiring contains no community/consultation mock
    - _PRD: §1 acceptance criteria; Success metrics_

- [ ] 15. Final checkpoint — Android production readiness
  - Confirm every PRD requirement and acceptance criterion has linked implementation and verification evidence
  - Confirm all release-blocking responsive checks pass and there are zero known Android layout blockers
  - Confirm progress-photo privacy, storage lifecycle, offline recovery, and upload-success telemetry are operational
  - Confirm community persistence, authorization, idempotent likes, comments, moderation controls, and operational ownership are ready
  - Approve the signed versioned Android App Bundle for release only after migration, rollback, backup, security, device-matrix, and privacy reviews pass

## Notes

- The root `PRD.md` is the source of truth for this plan.
- Tasks intentionally adopt the PRD’s default release dispositions: remove notifications, placeholder search, and mock-only consultation/trainer surfaces rather than expanding them into new features.
- CMake is not a supported product platform. Keep Android NDK/CMake tooling only when an audited Android dependency contains required native C/C++ code.
- Backend work uses Laravel; client work uses Flutter/Riverpod and the existing local database/synchronization architecture.
- Tests listed here are required by the PRD and are release work, not optional additions.
- Checkpoints require both automated validation and the specified Android physical-device smoke tests.
- Do not expose progress media through public predictable paths or include sensitive media URLs, passwords, descriptions, or private profile fields in logs.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "2.1", "3.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.4", "3.2", "3.3"] },
    { "id": 3, "tasks": ["4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.3", "5.4", "5.5", "5.6", "5.7"] },
    { "id": 4, "tasks": ["4.6", "5.2"] },
    { "id": 5, "tasks": ["6"] },
    { "id": 6, "tasks": ["7.1", "7.2", "8.1", "11.1"] },
    { "id": 7, "tasks": ["7.3", "7.4", "8.2", "8.3", "11.2"] },
    { "id": 8, "tasks": ["7.5", "8.4", "8.5", "11.3", "11.4", "11.5", "11.6", "12.1"] },
    { "id": 9, "tasks": ["9.1", "9.2", "9.3", "9.4", "9.5", "11.7", "12.2"] },
    { "id": 10, "tasks": ["9.6", "12.3", "12.4", "12.5"] },
    { "id": 11, "tasks": ["10", "12.6"] },
    { "id": 12, "tasks": ["13.1", "13.2", "13.3", "13.4"] },
    { "id": 13, "tasks": ["14.1", "14.2", "14.3"] },
    { "id": 14, "tasks": ["14.4"] },
    { "id": 15, "tasks": ["15"] }
  ]
}
```
