# Android Release and Operations Decisions

Status: **Approved baseline for implementation**  
Scope: `android-completion` task 1.1  
Source: `PRD.md` Goals 1–5, section 1 acceptance criteria, and Dependencies and risks

This record is the source of truth for downstream Android, progress-photo, community, QA, privacy, and release tasks. A change to a locked value requires Product Owner approval plus review by the accountable owner named below. Current repository configuration may not yet implement every decision; the final section identifies that expected drift.

## 1. Android release support

| Decision | Locked value |
| --- | --- |
| Supported runtime | Android only |
| Minimum Android version | Android 7.0, API 24 |
| Target Android version | Android 15, API 35; `compileSdk` must be at least 35 |
| Production ABIs | `arm64-v8a` (primary) and `armeabi-v7a` (compatibility) |
| Non-production ABI | `x86_64` may be used by emulator/debug builds, but it is not a supported production device ABI |
| Width range | 320–1,280 dp inclusive |
| Device classes | Phones (320–599 dp), tablets (600–1,280 dp), and foldables in both folded and unfolded states when each state remains within the supported width range |
| Explicit exclusions | Wear OS, Android TV, Android Auto, ChromeOS-specific behavior, widths below 320 dp or above 1,280 dp, and hinge-aware dual-pane layouts. Foldables use the same adaptive single-window layouts as phones/tablets. |
| Production application ID and namespace | `com.synchrofit.app` |
| Versioning | `MAJOR.MINOR.PATCH+BUILD`, sourced from `pubspec.yaml`. The semantic version describes the product release; `BUILD` is a positive, monotonically increasing Android `versionCode` and is never reused, including for rollback builds. |
| Release artifact | Android App Bundle only: `synchrofit-android-<MAJOR.MINOR.PATCH>-<BUILD>-release.aab` (example: `synchrofit-android-1.0.0-1-release.aab`) |

Release builds must not publish a universal APK. APKs generated for local QA are non-release artifacts and must include `qa` in their filename.

## 2. Signing ownership and secret handling

- **App-signing key owner:** the SyncroFit organization through Google Play App Signing. It must not be exported to developer workstations or CI.
- **Upload-key accountable owner:** Release Engineering Lead. The Product Owner and Security/Platform Lead are the two recovery approvers; no one person may both request and approve upload-key replacement.
- CI receives the upload keystore, alias, store password, and key password only through masked, protected secret variables scoped to the protected release environment and signed release tags. Secrets are unavailable to pull requests, fork builds, ordinary branches, job logs, caches, and artifacts.
- CI reconstructs the keystore in an ephemeral runner directory, generates signing properties at runtime, restricts file access to the build process, and deletes both files after the build. Values must never be passed on a command line, printed, or embedded in Gradle files.
- Local release signing, if needed for an approved recovery exercise, uses environment-injected values and untracked files. Keystores and signing property files are repository-ignored. Debug signing is forbidden for a production artifact.
- Upload-key rotation is annual or immediate after suspected disclosure. Rotation and recovery require an auditable ticket and the two approvers above.

The operational roster may map these accountable roles to named people in the protected release system; personal names and secret locations do not belong in this repository.

## 3. Release QA matrix

Every release candidate must pass the emulator matrix. The physical matrix validates device-only behavior such as camera capture, Photo Picker/provider integration, sharing, process restart, hardware decoding, insets, and real network transitions. Portrait and landscape are required for every row unless the row is explicitly a state transition. All widths are logical dp.

### Emulator matrix

| ID | API / image | Viewport or device state | Navigation / cutout | Required variants and focus |
| --- | --- | --- | --- | --- |
| E1 | API 24 | 320 × 568 compact phone | 3-button; no cutout | Portrait, landscape, 100% and 200% font; minimum-API and minimum-width coverage |
| E2 | API 28 | 360 × 720 phone | 3-button; simulated tall cutout | Portrait, landscape, 100% and 200% font; cutout-safe content and keyboard-open forms |
| E3 | API 29 | 412 × 915 phone | Gesture navigation; hole-punch/corner cutout profile | Portrait, landscape, 100% and 200% font; gesture insets and edge-to-edge actions |
| E4 | API 33 | 600 × 960 small tablet | Gesture navigation; no cutout | Portrait, landscape, 100% and 200% font; first tablet breakpoint and Photo Picker behavior |
| E5 | API 35 | Foldable at 412 dp folded and 840 dp unfolded | Gesture navigation; foldable/cutout profile | Both states, rotate in each state, 100% and 200% font; state change without lost work or overflow |
| E6 | API 35 | 1,280 × 800 large tablet | Gesture navigation; simulated cutout | Portrait-equivalent 800 × 1,280 and landscape 1,280 × 800, 100% and 200% font; maximum width and constrained content |

At 200% font scale, the full high-traffic flow is required: registration/login, dashboard, workout generation and active workout, exercise library/detail, progress/photos, community feed/composer/detail/comments, profile edit, settings, dialogs, and bottom navigation. Each row also runs with the keyboard open on forms and with denied-then-granted camera/media permissions where applicable.

### Physical-device matrix

| ID | Required device class | Minimum coverage |
| --- | --- | --- |
| P1 | API 24–28 phone, 320–360 dp, ARM (`armeabi-v7a` preferred when available) | Minimum-OS install/startup, portrait/landscape, 3-button navigation, camera, offline/reconnect, and constrained-memory restart |
| P2 | API 33–35 ARM64 phone, 360–430 dp, real cutout | Gesture navigation, 200% font, keyboard/insets, camera capture, Photo Picker, progress-photo upload/retry/delete/share, and all released tabs |
| P3 | API 33–35 ARM64 tablet, at least 600 dp | Portrait/landscape, 200% font, adaptive grid/list, dialogs, charts, community, comparison, and constrained readable width |
| P4 | API 33–35 foldable, when available | Folded/unfolded and rotation transitions during forms, workout, upload, comparison, and community composer. Until hardware is available, E5 is mandatory and the lack of P4 evidence is recorded as a release risk. |

A release is blocked by any platform exception, `RenderFlex` overflow, clipped or keyboard-obscured primary action, inaccessible 48 dp target, unsafe cutout/gesture inset, state loss across a fold/rotation, or failure at 200% font scale.

## 4. Progress-photo limits and media access

| Control | Locked value |
| --- | --- |
| Accepted MIME types | Content-sniffed `image/jpeg`, `image/png`, `image/heic`, and `image/heif`. File extensions and client headers are not authoritative. Malformed, animated/multi-frame, or undecodable input is rejected. |
| Maximum upload size | 15 MiB (15 × 1,024 × 1,024 bytes) per source image |
| Maximum dimensions | No edge above 12,000 pixels and no more than 48 megapixels after orientation is applied |
| Display derivative | Fit within 2,048 × 2,048 pixels, no upscaling, WebP quality 85 |
| Thumbnail | Fit within 512 × 512 pixels, no upscaling, WebP quality 80; preserve aspect ratio rather than crop |
| Timeout | 15-second connection timeout and 120-second total timeout per upload attempt, including server processing; image processing itself is limited to 30 seconds |
| Retry limit | At most three automatic attempts total (initial plus two retries) with jittered exponential backoff. A manual retry reuses the same client-operation/idempotency key until the operation is resolved. Permanent validation/quota failures are never auto-retried. |
| Per-user quota | 500 retained photos and 5 GiB of retained sanitized originals, whichever is reached first. Pending offline items show quota failure after server validation and remain actionable for removal. |
| EXIF/metadata | Apply orientation, then strip all EXIF, GPS, IPTC, XMP, device, and embedded-comment metadata from the stored full-resolution asset and all derivatives. The raw upload is deleted after successful sanitization or any failed attempt. The user-selected `captured_on` value is authoritative; metadata never silently changes it. |
| Signed URL | Prefer an authorized streaming endpoint. If a signed URL is used, its hard maximum lifetime is 5 minutes. It is HTTPS, GET-only, bound to one exact object after an ownership check, non-listable/non-writable, and returned with private/no-store cache policy. URLs/tokens must not be logged, analyzed, persisted, or included in notifications; the client requests a new URL after expiry. |

Validation occurs before a database record becomes visible. A failed or timed-out operation must leave neither a record nor a retained raw/derived object. Share-card files are app-private temporary files, are not uploaded or made public, and are removed after the share lifecycle or by the next startup cleanup.

## 5. Private storage, retention, backup, and privacy

### Storage selection

- Use a dedicated **Amazon S3 private bucket** through Laravel's `s3` storage disk, in the approved production region shared with the backend/database data residency boundary.
- Enable S3 Block Public Access at account and bucket levels. Disable public ACLs and public bucket policies. Use TLS in transit and SSE-KMS at rest with a production key owned by Security/Platform.
- Give the backend workload identity only object read/write/delete access under the environment-specific progress-photo prefix. CI and developers do not receive production object credentials; production credentials come from protected environment/secret management.
- Use opaque object keys unrelated to email, display name, or original filename. Bucket names, object keys, signed URLs, and media descriptions are excluded from application logs and analytics.

### Retention and deletion

- Active photos and derivatives are retained until the member deletes the photo or the account is deleted; there is no inactivity expiry.
- A delete request makes the record and media unavailable synchronously, then permanently purges the original and every derivative within 24 hours. Failed purges are retried and surfaced by orphan reconciliation/alerts. Deletion is idempotent.
- Confirmed account deletion applies the same rule to all progress media and completes active-object purge within 24 hours. No media is retained for product analytics or model training.
- S3 object versioning and independent object backup are disabled for this bucket so a purge does not leave recoverable image versions. S3 multi-AZ durability is the availability mechanism; accidental media deletion is not recoverable.
- Encrypted database backups may retain photo metadata (not image bytes) for 30 days. Backups are access-restricted, are used only for disaster recovery, and expire automatically. A restore must replay deletion tombstones before restored data can serve traffic. Any legally required exception must be approved by Privacy/Legal and disclosed when law permits.

### Required privacy-policy and store disclosures

Before the controlled beta accepts photo uploads, the Android privacy policy and Play Data safety declaration must disclose:

1. collection of private progress images, optional descriptions, selected dates, account identifiers, and operational upload metadata;
2. purposes: private progress tracking, synchronization, comparison, explicit sharing, security, and support—never advertising or biometric/body-composition inference;
3. Amazon Web Services as the object-storage processor, applicable data region, encryption, and restricted operator access;
4. the retention, 24-hour active deletion target, no image backup/version history, and 30-day metadata-backup behavior above;
5. that EXIF/location/device metadata is stripped, authorization or five-minute URLs protect viewing, and private photos are not public by default;
6. camera and photo-selection permission purpose, denial behavior, and Android system-sharing behavior, including that the member chooses the external recipient/app;
7. in-app photo/account deletion controls, privacy contact, incident contact, effective date, and notification/consent process for material changes.

Privacy/Legal owns wording approval; Product owns publishing and the Play declaration; Engineering must verify implementation matches the published policy before beta.

## 6. Community moderation and launch controls

### Ownership and escalation

- **Accountable owner:** Community Operations Lead.
- **Daily queue and first response:** assigned Community Moderator; at least two trained people (primary and backup) must appear in the protected on-call roster before beta.
- **Technical enforcement/audit owner:** Backend Lead.
- **Privacy or legal escalation:** Privacy/Legal owner. **Security threats:** Security/Platform on-call. **Release go/no-go:** Product Owner.
- P0 reports (credible imminent harm, child safety, exposed highly sensitive personal data, or credible security threat) page the on-call owner immediately, target acknowledgement within 1 hour, restrict visibility while reviewed, and escalate to Privacy/Legal or emergency channels as applicable.
- P1 reports (targeted harassment, hate, threats without stated immediacy, repeated evasion) target acknowledgement within 4 hours and resolution within 24 hours.
- P2 reports (spam, off-topic content, ordinary conduct issues) target acknowledgement within 1 business day and resolution within 3 business days.
- Moderator actions require a reason, actor, timestamp, target, prior/new state, and correlation ID in an append-only audit trail. Audit entries retain for 12 months and never copy full private profile data unnecessarily.

### Rate limits

Limits apply per authenticated user; a secondary per-IP ceiling of five times the user limit mitigates account farms. Exceeding a limit returns `429` with `Retry-After`. Idempotent retries that do not create a new state must not inflate counters.

| Action | Burst limit | Sustained limit |
| --- | --- | --- |
| Create post | 5 per 10 minutes | 20 per 24 hours |
| Create comment | 20 per 10 minutes | 100 per 24 hours |
| Like/unlike state changes | 60 per minute | 500 per 24 hours |
| Submit report | 10 per hour | 20 per 24 hours |
| Feed/detail reads | 120 per minute | No daily ceiling |

Thresholds are protected environment configuration, with these values as production defaults. Tightening them during an incident is allowed and audited; relaxing them requires Community Operations and Backend Lead approval.

### Reporting approach

Before beta, authenticated members must be able to report a post or comment in-app using a server endpoint. Reasons are harassment, hate/threats, spam, sexual/violent content, self-harm concern, privacy/personal data, and other; optional detail is limited to 500 characters. The server records reporter, target, reason, timestamps, and status, deduplicates one open report per reporter/target, acknowledges receipt without revealing enforcement, and places it in the moderation queue. Users may also report an account through the published support channel. Blocking, appeals, and a standalone moderator console may follow later, but operators need an authenticated command/admin mechanism to hide/restore content and record the audit event before beta.

### Launch decision

Community launches as an **invite-only controlled beta**, initially capped at 500 accepted members. Public launch is prohibited until all of the following are evidenced:

- the beta has run for at least 14 consecutive days with the primary and backup moderation roster staffed;
- in-app reporting, operator hide/restore, rate limits, audit trail, alerts, terms acceptance, and published community guidelines are operational;
- no unresolved P0/P1 report is outside its SLA, authorization tests pass, and no private profile fields appear in responses/logs;
- Community Operations, Backend, Privacy/Legal, Security/Platform, and Product record go/no-go approval.

## 7. Implementation gates and current repository drift

These decisions do not mark downstream implementation complete. The following known drift is release-blocking and belongs to subsequent tasks:

- `android/app/build.gradle.kts` still uses `com.example.synchrofit`, Flutter-derived SDK defaults, and debug signing for release. It must adopt the locked identity/API/signing values.
- `pubspec.yaml` currently contains `1.0.0+1`; future releases must increment according to the locked scheme and CI must emit the locked artifact name.
- ABI filtering, protected CI signing, and Android-only artifact publication are not yet configured.
- The Laravel project does not yet include/configure the S3 adapter or private progress-photo disk.
- Progress-photo processing, deletion reconciliation, privacy text/store declarations, community reporting/moderation controls, and the named protected operational rosters must exist and be approved before the controlled beta.

No production artifact may be approved while any applicable gate in this record remains unmet.
