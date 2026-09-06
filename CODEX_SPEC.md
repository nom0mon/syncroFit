# SyncroFit Final Features — Codex Development Spec

## Purpose

This is the living implementation contract and progress tracker for the final
SyncroFit features. Codex must update this file as requirements are clarified,
tasks are completed, tests are added, and implementation decisions change.

This document is independent of `.kiro/specs/`. Existing application behavior
must remain working unless a requirement below explicitly replaces it.

## Status legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Completed and verified
- `[!]` Blocked; the reason must be recorded in the decision log

## Product-wide requirements

- Android is the supported client platform.
- All new screens must support 320–1280 dp widths, portrait and landscape,
  large text, gesture navigation, display cutouts, and keyboard-open states.
- Every primary action must remain visible or reachable by scrolling.
- All authenticated data must be scoped to the current user.
- New mutable data must integrate with the existing local-cache and offline
  synchronization architecture where practical.
- Loading, empty, validation, offline, retry, success, and failure states must
  be explicit.
- Backend authorization must prevent users from reading or changing another
  user's records.
- Feature completion requires Flutter tests, Laravel tests, static analysis,
  and proportionate Android manual verification.

## Delivery order

1. BMI calculator
2. Recommended workout customization and fitness-level prescription
3. Progress logging
4. Community posts, likes, and comments
5. Cross-feature regression and Android release verification

---

## Feature 1: BMI Calculator

### User outcome

A user with a profile automatically sees their BMI in Progress. A user without
a profile sees a clear prompt and can navigate to profile setup before BMI is
calculated.

### Functional requirements

- BMI is calculated as `weightKg / (heightCm / 100)^2`.
- Display BMI rounded to one decimal place.
- Use the current profile height and weight as the source of truth.
- Recalculate immediately after either profile value changes.
- Do not ask a profiled user to re-enter height or weight in Progress.
- When no profile exists, show an empty state explaining what is missing and a
  `Set Up Profile` action.
- Invalid or zero height/weight values must not produce `NaN`, infinity, or a
  misleading BMI.
- Display the standard category label:
  - Underweight: below 18.5
  - Healthy: 18.5–24.9
  - Overweight: 25.0–29.9
  - Obesity: 30.0 and above
- Categories are informational and must not be presented as medical advice.

### Acceptance criteria

- A profile containing 70 kg and 175 cm displays BMI `22.9` and `Healthy`.
- Updating weight or height updates the Progress BMI without restarting.
- An absent profile displays the setup prompt and no numerical BMI.
- Boundary and invalid-input unit tests pass.

### Tasks

- [x] Add a pure BMI calculation/category utility with boundary tests.
- [x] Add BMI state derived from `profileProvider`.
- [x] Add the responsive BMI card and missing-profile state to Progress.
- [x] Add profile-change and responsive widget tests.
- [x] Verify profile setup/edit refreshes BMI immediately.

---

## Feature 2: Recommended Workout Customization

### User outcome

A user can add exercises to or remove exercises from a recommended scheduled
workout. The system—not the user—assigns bounded sets, reps or duration, and
rest periods using the user's fitness level, fitness goal, and exercise type.

### Functional requirements

- Provide `Customize Workout` from each recommended scheduled workout.
- Show the current ordered exercise list and an exercise-library picker.
- Allow adding an exercise that is not already in the workout.
- Allow removing an exercise while retaining at least one exercise.
- Allow reordering exercises if it does not conflict with the generated-plan
  contract.
- Do not expose editable controls for sets, reps, duration, or rest.
- Every added exercise receives a prescription from one centralized policy.
  Fitness level controls starting volume and progression; fitness goal and
  exercise type control reps/duration and rest within level-specific bounds.
- Existing exercises are normalized through the same policy when the user's
  fitness level changes.
- Rest applies after every set except the last set of the final exercise.
- Save customizations persistently and refresh workout detail, active workout,
  schedule, and progress-related consumers.
- Prevent duplicate exercises and handle stale/deleted library exercises.
- The customization request contains exercise IDs and order only. The backend
  rejects client-supplied prescription fields and derives all prescription
  values from the authenticated user's current profile.
- Advanced users must not automatically receive shorter rest, unnecessary
  additional exercises, or routine failure training.

### Prescription policy

Exact values must live in one backend policy/service and be mirrored only for
display or tests in Flutter. The evidence and rationale are documented in
`docs/resistance-training-prescription-policy.md`.

#### Level policy

| Fitness level | Working sets per exercise | Starting weekly sets per muscle | Effort guidance |
|---|---:|---:|---|
| Beginner | 2 | 4–8 | Stop with 3–4 repetitions in reserve |
| Intermediate | 3 | 8–12 | Stop with 2–3 repetitions in reserve |
| Advanced | 3; 4 only for one designated priority lift | 10–16 | Stop with 1–3 repetitions in reserve |

Warm-up sets do not count. Ordinary advanced exercises use three working sets;
experience alone is not a reason to add fatiguing volume. Four sets are allowed
only when the policy can identify a single priority lift; otherwise use three.

#### Goal and exercise-type policy

| Goal/exercise type | Reps or duration | Rest after every working set |
|---|---:|---:|
| Strength-oriented primary compound | 3–6 reps | 180 seconds; advanced may use up to 300 seconds |
| Hypertrophy compound | 6–12 reps | 120–180 seconds |
| Hypertrophy isolation or machine | 10–20 reps | 60–120 seconds |
| Muscular endurance | 12–20 reps | 60–90 seconds; extend when target reps cannot be maintained |
| Timed bodyweight or isometric | 20–45 seconds | 60–120 seconds |

For current profile goals, `build_muscle` maps to hypertrophy,
`increase_stamina` maps to muscular endurance, and `stay_fit`/`lose_weight`
use a general-fitness prescription of 8–12 reps with 90–120 seconds rest.
Exercise metadata selects compound, isolation/machine, or timed behavior.

When metadata is absent or stale, the deterministic safe fallback is the
level's set count, 8–12 reps, and 120 seconds rest. The current workout contract
stores a single integer target, selected deterministically from the applicable
range rather than randomized on each request.

#### Redundancy and fatigue policy

- Add primary movement pattern, primary muscles, secondary muscles, exercise
  type, and angle/region metadata where the exercise library lacks it.
- Prefer 4–6 resistance exercises per workout where the library permits.
- Permit at most two exercises with the same primary muscle and movement
  pattern in one workout. The second must provide a meaningfully different
  angle/region or resistance profile.
- Cap one muscle at 10 direct working sets per session. For weekly accounting,
  direct sets count as `1.0` and compound secondary-muscle sets as `0.5`.
- Do not add exercises merely because the user is advanced. Preserve core
  movements for a 4–8 week block and vary them deliberately, not randomly.
- Do not prescribe routine compound-lift failure. If failure guidance is added
  later, limit it to the final set of a low-risk isolation/machine exercise.
- Reject a customization that breaches movement-pattern or muscle-volume
  limits and return a specific, actionable validation message.

### Audit findings (2026-09-05)

- The backend currently selects `2–3`, `3–4`, or `4–5` sets for beginner,
  intermediate, or advanced users respectively.
- Reps currently depend on fitness goal rather than fitness level and are
  randomized within these ranges: lose weight `12–20`, build muscle `6–12`,
  stay fit `8–15`, and increase stamina `15–20`.
- Timed exercises use each exercise's default duration without fitness-level
  adjustment.
- Estimated workout duration assumes 60 seconds between sets, but that rest
  value is not persisted.
- The Flutter active workout currently uses a fixed 30-second rest.
- The Flutter workout model treats legacy `rest_seconds` as a fallback for
  `duration_seconds`, conflating rest time with exercise duration.
- There is no authenticated workout-update/customization endpoint.

The research-aligned prescription policy was approved for implementation on
2026-09-05.

### Data/API requirements

- Add/update an authenticated endpoint for modifying a generated workout's
  ordered exercise IDs.
- Derive prescription fields server-side from the authenticated profile.
- Persist exercise order and the resulting prescription.
- Include `rest_seconds` explicitly in the workout-exercise contract; do not
  overload exercise duration as rest time.
- Reject empty, duplicate, unknown, unauthorized, or malformed exercise lists.
- Return structured validation errors for redundant movement patterns and
  muscle-volume limits so Flutter can explain why an exercise cannot be added.
- Re-normalize non-completed recommended workouts after a fitness-level or
  fitness-goal change; never rewrite completed workout history.

### Acceptance criteria

- Adding an exercise saves it with level-derived parameters.
- Removing an exercise persists after app restart/refetch.
- A user cannot submit arbitrary sets, reps, duration, or rest through the API.
- Changing fitness level re-normalizes future/recommended workout parameters.
- Changing fitness goal re-normalizes future/recommended workout parameters.
- The active workout rests after every set using the prescribed rest value.
- Advanced users receive no shorter rest solely because of experience level.
- Redundant exercises and muscle-volume violations are prevented with an
  actionable message.
- Completed workouts retain their historical prescription after profile
  changes.

### Tasks

- [x] Audit the recommendation engine and define the prescription table.
- [x] Specify and migrate the workout-exercise rest field if absent.
- [x] Add backend customization validation, policy, endpoint, and tests.
- [x] Add repository/cache/sync support for workout customization.
- [x] Build the responsive customization screen and exercise picker.
- [x] Refresh all workout consumers after saving.
- [x] Add provider, widget, API-contract, authorization, and regression tests.

---

## Feature 3: Progress Logging

### User outcome

A user can create a dated visual progress log containing a title, description,
current weight, and image. Progress displays newest first and is separated into
month sections.

### Functional requirements

- Add a `Log Progress` action to Progress.
- Each log requires:
  - title
  - description
  - current weight in kilograms
  - one image selected from the gallery or captured with the camera
  - a server-controlled creation timestamp
- Validate title and description length, positive plausible weight, supported
  image type, file size, and dimensions.
- Show an image preview before saving.
- Show upload progress, prevent duplicate submissions, and support retry.
- Display logs newest to oldest.
- Group logs into month/year sections based on the user's local timezone, for
  example `September 2026`, then `August 2026`.
- Logs within each section are ordered by creation timestamp descending.
- A user can open a log detail view and delete their own log with confirmation.
- Saving a progress log does not automatically overwrite profile weight. The UI
  may offer a separate explicit `Update profile weight` choice in a later spec.
- Empty, loading, offline, failed-image, and no-permission states are required.

### Data/API requirements

- Add `progress_logs` with id/UUID, user ID, title, description, weight,
  private original image path, display/thumbnail path, and timestamps.
- Index `(user_id, created_at)`.
- Add authenticated endpoints for paginated list, create via multipart, show,
  and delete.
- Use private storage and authorized delivery or expiring URLs.
- Deleting a log must remove owned image derivatives without exposing or
  deleting another user's media.
- Offline drafts may be stored locally, but binary upload must clearly show a
  pending/retry state until synchronization succeeds.

### Acceptance criteria

- A valid log appears at the top immediately after a successful save.
- Logs spanning multiple months render under correct month/year headings.
- Another user cannot view or delete the log or its image.
- Invalid/oversized files are rejected by client and server.
- Camera/gallery denial leaves the rest of Progress usable.

### Tasks

- [x] Finalize field limits, file limits, and offline-draft behavior.
- [x] Add backend migration, model, policy, storage service, endpoints, and tests.
- [x] Add Flutter model, repository, cache metadata, and sync behavior.
- [x] Add Android camera/media permission handling.
- [x] Build create, grouped timeline, detail, retry, and delete experiences.
- [x] Add grouping, serialization, repository, permission, upload, and
      responsive widget tests.

**Checkpoint:** Approved by the user on 2026-09-05 after successful Chrome
gallery, camera capture, and save testing.

---

## Feature 4: Community Module

### User outcome

Authenticated users have a simple social feed where they can publish text
posts, like/unlike posts, and comment. Reposts and sharing are not included.

### Functional requirements

- Display a latest-first paginated home feed.
- A post contains author identity, text content, timestamps, like count,
  comment count, and whether the current user liked it.
- A post may be text-only or contain up to four photos.
- Supported photos are JPEG, PNG, and WebP, up to 8 MB each and 4096×4096.
- Show selected-media previews and upload progress before publishing.
- Users can create posts and delete their own posts with confirmation.
- Users can like once, unlike, add comments, and delete their own comments.
- Like actions must be idempotent and safe from rapid duplicate taps.
- Post detail shows comments in a documented deterministic order.
- Repost and share controls must not appear.
- Long content and names must wrap safely; loading, empty, pagination, retry,
  optimistic-update rollback, and deleted-content states are required.
- Store author ownership for moderation readiness; admin UI is out of scope.

### Data/API requirements

- Add `posts`, `post_likes`, and `comments` tables with foreign keys, useful
  indexes, timestamps, and appropriate cascading/soft-delete behavior.
- Add ordered `post_media` records containing post ownership, media type,
  storage disk/key, MIME type, byte size, and optional dimensions/duration.
- Store media objects through Laravel's filesystem abstraction. Use private
  local storage in development and an S3-compatible object-storage bucket in
  production; never store binary media in the relational database.
- Return authorized temporary URLs (or an authenticated local-media response)
  and delete media objects when their owning post is permanently purged.
- Enforce one like per `(post_id, user_id)` with a unique database constraint.
- Add authenticated paginated feed/create/show/delete post endpoints.
- Add authenticated like/unlike and list/create/delete comment endpoints.
- Return 404 for inaccessible records and 403 for forbidden mutations without
  leaking private information.
- Replace the mock community repository with remote, cache-aware data.

### Acceptance criteria

- A new post appears at the top of the feed.
- Like/unlike produces correct counts and never creates duplicate likes.
- Comments persist, update counts, and display in the defined order.
- Users cannot delete content owned by someone else.
- Feed pagination does not duplicate or omit posts during normal use.
- No repost/share UI or API is present.
- Valid photo posts upload, render in feed/detail, and remain bounded by the
  documented count, type, size, and dimension limits.

### Tasks

- [x] Audit and reconcile existing mock community models/screens.
- [x] Define field limits, comment ordering, pagination, and delete semantics.
- [x] Add backend migrations, models, policies, endpoints, and tests.
- [x] Implement remote/cache repositories and replace mock wiring.
- [x] Build/complete post composer, feed, likes, detail, comments, and deletes.
- [x] Add optimistic update rollback and refresh behavior.
- [x] Add authorization, pagination, repository, provider, and responsive tests.
- [x] Add Community photo upload, storage metadata, previews, rendering,
      cleanup, and validation tests.

---

## Cross-feature verification

### Device-test follow-ups

- [x] Restore the authenticated user and token from secure local storage so a
      previously signed-in user can reopen cached workouts while offline.
- [x] Replace the generic offline workout-customization failure with an
      explicit connection requirement that confirms the saved plan is intact.
- [ ] Add an explicit accept/approve step after workout generation.
- [ ] Remove the 50-character first/last-name restrictions across Flutter,
      Laravel validation, and database storage.
- [ ] Add a unique customizable username, populate profile names from signup,
      and prevent duplicate usernames.
- [ ] Calculate weekly progress against the actual scheduled days and prevent
      the completed count from exceeding the planned count.

- [ ] All new backend migrations run on a clean database and upgrade an
      existing development database.
- [ ] API responses and Flutter serializers agree on nullability and types.
- [ ] Authentication/account switching clears user-scoped state.
- [ ] Offline queue operations are idempotent and conflict behavior is tested.
- [ ] Dashboard, workout, profile, Progress, and Community regressions pass.
- [ ] No uncaught Flutter exceptions, render overflow, or blocked actions at
      supported Android configurations.
- [ ] `flutter analyze` passes.
- [ ] Flutter test suite passes.
- [ ] Laravel test suite passes.
- [ ] Android release build succeeds.
- [ ] Manual smoke test completes on an emulator or device.

## Out of scope

- Medical diagnosis or personalized medical advice based on BMI.
- User-defined sets, reps, duration, or rest values.
- Automatic publication of private progress logs to Community.
- Community reposts, shares, direct messages, following, groups, stories, or
  real-time chat.
- iOS, web, Windows, Linux, or macOS release work.

## Open decisions

These must be resolved before their dependent task begins:

No unresolved decisions currently block implementation.

## Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-09-05 | Use this root `CODEX_SPEC.md` as the living tracker. | The user requested a Codex development spec rather than a Kiro spec. |
| 2026-09-05 | Deliver features in dependency/risk order: BMI, workout customization, progress logs, Community. | Profile-derived BMI is smallest; media and social systems carry larger backend and storage dependencies. |
| 2026-09-05 | Treat progress logs as private and do not auto-publish them. | Progress and Community have distinct privacy expectations. |
| 2026-09-05 | Treat Community v1 posts as text-only. | The requested scope specifies posts, comments, and likes but does not request community media. |
| 2026-09-05 | Derive the Progress BMI from live profile measurements. | The backend already persists a computed BMI, but deriving it from `profileProvider` guarantees immediate updates and keeps invalid-value handling explicit. |
| 2026-09-05 | Pause workout prescription implementation pending policy confirmation. | The existing system has contradictory rest values and derives reps from goals, while the requested feature requires fitness-level-controlled sets, reps, and rest. |
| 2026-09-05 | Align Feature 2 with the resistance-training evidence review. | Current evidence supports level-based volume, goal/type-based reps and rest, adequate rest to preserve performance, limited failure work, and explicit redundancy/volume safeguards. |
| 2026-09-05 | Approve the research-aligned Feature 2 policy for implementation. | The user instructed Codex to proceed after reviewing the aligned specification and workout-detail context. |
| 2026-09-05 | Store `rest_seconds` in the existing workout exercise JSON rather than add a table column. | Workouts already persist their exercise contract as JSON; separating rest from `duration_seconds` requires a contract migration, not a schema column. |
| 2026-09-05 | Keep customization online-only while caching successful server responses. | The server must validate prescriptions and fatigue limits, so an offline edit cannot be safely finalized; the UI reports network failure and preserves existing cached workouts. |
| 2026-09-05 | Limit progress logs to a 100-character title, 1,000-character description, 20–500 kg weight, and one JPEG/PNG/WebP image up to 5 MB and 4096×4096 pixels. | These bounds support useful logs while limiting unsafe values, storage abuse, and excessive mobile uploads. |
| 2026-09-05 | Make progress-log creation an online upload with retry; cache saved log metadata for offline reading. | Persisting and synchronizing private image binaries safely requires a larger encrypted draft subsystem and is not necessary for a clear retry experience. |
| 2026-09-05 | Store separate private original and display copies of each progress image. | This satisfies the media contract without requiring server image-processing extensions; authorized delivery exposes only the display copy. |
| 2026-09-05 | Use byte-based progress-image preview and upload, and invoke the custom permission channel only on Android. | File-path preview/upload and an unconditional Android channel prevented gallery/camera use on web-compatible builds; bytes work across supported picker implementations. |
| 2026-09-05 | Restore the Flutter web runner and use `camera_web` for Chrome webcam capture. | The project had no web runner and `image_picker_for_web` only offers HTML mobile capture rather than a desktop Chrome live-camera controller. |
| 2026-09-05 | Let the Chrome camera dialog own and dispose its `CameraController`. | Keeping controller disposal outside the preview dialog allowed `CameraPreview` to rebuild after the controller had already been disposed. |
| 2026-09-05 | Detect captured progress-image formats from JPEG/PNG/WebP file signatures and normalize generated filenames. | Chrome webcam captures may use blob filenames without extensions or MIME metadata even though their encoded image bytes are valid. |
| 2026-09-05 | Limit Community posts to 2,000 characters and comments to 500; paginate feeds by 15 and display comments oldest first. | These limits support substantial text while keeping mobile rendering and payloads bounded; chronological comments preserve conversational reading order. |
| 2026-09-05 | Soft-delete Community posts and comments while cascading likes with their post. | Soft deletion supports moderation/audit readiness and deleted-content states without retaining meaningless like rows. |
| 2026-09-06 | Limit Community media to four photos per post and remove video posting from scope. | The user chose a simpler photo-only experience that reduces storage, upload, playback, and moderation complexity. |
| 2026-09-06 | Store Community media on a Laravel filesystem disk backed by private S3-compatible object storage in production, with only object keys and metadata in SQL. | Object storage scales independently from application servers, works with temporary URLs/CDNs, and avoids database bloat or data loss during stateless deployments. |
| 2026-09-06 | Scope profile and workout cache freshness/data reads to the authenticated user and rebuild user-state providers when the user ID changes. | Global cache keys and persistent providers could serve stale empty or previous-account state after registration/login transitions. |
| 2026-09-06 | Use one filled circle solely for the dashboard's selected calendar day; represent other completed dates with dots. | Separate completed, today, and selected rings made two dates appear selected and obscured tap feedback. |
| 2026-09-06 | Send explicit photo MIME types in Community multipart uploads and surface field-specific validation messages. | Browser byte uploads may otherwise arrive as generic binary files, while a generic “Validation failed” message concealed the actionable server response. |
| 2026-09-06 | Make dashboard calendar outlines represent recurring scheduled workout weekdays, and make the selected date reveal its workout card. | The calendar is for schedule discovery; completion remains a separate dot indicator and selection remains a single filled circle. |
| 2026-09-06 | Encode Community images as repeated `photos[]` multipart file entries. | Laravel only validates the upload as an array when PHP receives array-style multipart field names. |
| 2026-09-06 | Drive dashboard calendar outlines from `scheduledWorkoutsProvider`, the same mapped source used by the recommendations weekly plan. | Raw workout weekdays can differ from scheduler fallback assignments based on the user's availability. |
| 2026-09-06 | Preserve Community photo contents with contained fitting and allocate a square gallery for three or four photos. | A fixed 16:9 gallery cropped portrait images and clipped the second row of a four-photo grid. |
| 2026-09-06 | Restore offline authentication from a securely cached user identity paired with the existing secure token. | A token alone could authorize cached requests but could not reconstruct account-scoped application state after a cold offline restart. |
| 2026-09-06 | Keep workout customization online-only and state that requirement explicitly in the UI. | The backend must recalculate and validate level-based sets, reps, and rest; silently queueing only exercise IDs could apply against a changed plan later. |
| 2026-09-06 | Fall back to account-scoped SQLite profile/workout records whenever an optimistic cold-start request fails, and write generated plans through the caching repository. | Device testing showed authentication survived restart while profile and workout data disappeared because reachability detection completed after providers attempted remote reads. |
| 2026-09-06 | Query cached profiles by authenticated user ID instead of returning the first SQLite row. | Direct device-database inspection showed multiple valid account profiles; returning Simon's first row caused Aquil's profile check to fail and prevented schedule construction offline. |

## Progress summary

| Feature | Status | Completed tasks | Total tasks |
|---|---|---:|---:|
| BMI Calculator | Complete — approved | 5 | 5 |
| Workout Customization | Complete — awaiting user review | 7 | 7 |
| Progress Logging | Complete — approved | 6 | 6 |
| Community | Complete — photo extension awaiting user review | 8 | 8 |
| Cross-feature verification | Not started | 0 | 10 |

## Update protocol for Codex

For every implementation session involving these features, Codex must:

1. Read this file before changing code.
2. Identify the next unchecked task and relevant acceptance criteria.
3. Mark only the active task `[~]` while work is in progress.
4. Add or update tests with the implementation.
5. Mark a task `[x]` only after its acceptance criteria are verified.
6. Record blockers, scope changes, and material decisions in the decision log.
7. Update the progress summary before handing work back to the user.
