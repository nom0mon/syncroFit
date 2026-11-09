# SyncroFit: System Manual & Presentation Walkthrough

**SYNCROFIT: A Mobile-Based Fitness Management Application with Personalized Exercise Set Recommendations**
*Prepared for: Presentation Review | City College of Calamba — BS Information Technology, 2026*

---

## Table of Contents

1. [System Overview (The 5Ws)](#1-system-overview-the-5ws)
2. [Feature 1: User Registration & Login](#2-feature-1-user-registration--login)
3. [Feature 2: Initial Assessment (Onboarding)](#3-feature-2-initial-assessment-onboarding)
4. [Feature 3: Dashboard & Workout Schedule Calendar](#4-feature-3-dashboard--workout-schedule-calendar)
5. [Feature 4: Workout Generator (Personalized Recommendations)](#5-feature-4-workout-generator-personalized-recommendations)
6. [Feature 5: Workout Customization](#6-feature-5-workout-customization)
7. [Feature 6: Active Workout & Rest Timer](#7-feature-6-active-workout--rest-timer)
8. [Feature 7: BMI Calculator & Progress Summary](#8-feature-7-bmi-calculator--progress-summary)
9. [Feature 8: Progress Logging (Photo & Weight Logs)](#9-feature-8-progress-logging-photo--weight-logs)
10. [Feature 9: Community Feed (Social Module)](#10-feature-9-community-feed-social-module)
11. [Feature 10: Exercise Library](#11-feature-10-exercise-library)
12. [Feature 11: Profile Management](#12-feature-11-profile-management)
13. [Feature 12: Settings](#13-feature-12-settings)
14. [Feature 13: Workout Reminders (Local Notifications)](#14-feature-13-workout-reminders-local-notifications)
15. [How Features Connect (Cross-Feature Relationships)](#15-how-features-connect-cross-feature-relationships)
16. [Technology Stack Summary](#16-technology-stack-summary)
17. [Scope & Limitations for Presentation](#17-scope--limitations-for-presentation)

---

## 1. System Overview (The 5Ws)

### What is SyncroFit?
SyncroFit is a **mobile-based fitness management application** for Android. It provides users with personalized exercise set recommendations, a structured workout scheduling system, BMI tracking, visual progress logging through timestamped photos, and a community social feed — all in one platform. It uses a **rule-based recommendation engine** (not AI or machine learning) that generates workout plans based on each user's BMI, fitness goal, and fitness level.

### Who is it for?
SyncroFit is designed for four types of users:
- **Gym members** at LF Fitness Gym (Calamba, Laguna) who want structured, personalized routines without relying entirely on trainers for every session.
- **Home workout individuals** who exercise without equipment and need guided workout plans.
- **Fitness enthusiasts** who want one platform for planning, tracking, and reviewing their progress.
- **Beginner users** with limited exercise knowledge who need clear guidance on what to do, how many sets, and how long to rest.

### Where is it used?
SyncroFit is an **Android mobile application**. It runs on Android smartphones and supports three training locations:
- **Gym** — full equipment available (barbells, cables, machines, dumbbells)
- **Home** — bodyweight exercises only (no equipment assumed)
- **Outdoor** — bodyweight and plyometric exercises

### When is it used?
Users interact with SyncroFit:
- **Before a workout** — to check their schedule, review their plan, or generate a new plan.
- **During a workout** — to follow the active workout screen with a guided set/rep tracker and automatic rest timer.
- **After a workout** — to mark completion, review their summary, and log visual progress.
- **Regularly** — to receive 8:00 AM local notification reminders on their scheduled workout days.

### Why was it built?
The problem it solves: LF Fitness Gym relied on **manual, verbal, and generalized** fitness guidance. Clients faced:
- Difficulty choosing the right exercises for their goal and fitness level.
- No digital progress tracking (relied on memory, handwritten notes, or social media comparisons).
- Inconsistent workout routines due to lack of structured planning.
- Repeated dependence on trainers for basic workout information.

SyncroFit bridges that gap with an accessible, automated, and personalized fitness management platform — reducing trainer dependency for routine planning while letting trainers focus on clients who need more specialized attention.

---

## 2. Feature 1: User Registration & Login

### What it does
Manages secure account creation and authentication using email and password. Users sign up with a unique username (displayed publicly in Community), an email address, and a password. Returning users log in using email and password.

### How it works (step by step)
1. **Sign Up** — User taps "Sign Up" on the login screen and enters: username, email, and password.
2. **Login** — User enters email and password, taps "Sign In."
3. **Forgot Password** — User taps "Forgot Password?", enters their email, and receives a secure link via email (delivered through Brevo's HTTPS API). The link leads to a backend-hosted reset form that expires after use and revokes existing API tokens.
4. After successful login or signup, the user is directed to the **Assessment** flow (first time) or straight to the **Dashboard** (returning user).

### How it benefits users
- Keeps all fitness data private and scoped per account.
- Username (not full name) is used as the public identity in Community posts, protecting personal privacy.
- Password recovery is available through a secure, expiring email link — no technical support needed.

### Connections to other features
- Login state drives all authenticated API calls throughout the app.
- Logging out clears all user-scoped state (profile, workouts, community data) so no data leaks between accounts.

---

## 3. Feature 2: Initial Assessment (Onboarding)

### What it does
A 3-step guided onboarding flow completed **once** after registration. It collects the information needed to personalize everything else in the app.

### How it works (step by step)

**Step 1 — Body Measurements:**
- User enters: height (cm) and weight (kg).
- These values are used to calculate BMI and to determine the intensity of workout prescriptions.

**Step 2 — Physical Info:**
- User enters: age, gender, and activity level (Sedentary / Lightly Active / Moderately Active / Very Active).
- Activity level provides context for workout intensity and endurance-related recommendations.

**Step 3 — Goals:**
- User selects their **Fitness Goal** from four options:
  - **Lose Weight** — focus on calorie burn and fat loss
  - **Build Muscle** — strength training and muscle growth
  - **Maintain Fitness** — keep current fitness level
  - **Improve Endurance** — cardio and stamina improvement
- User enters **Training Experience (years)** — used to determine fitness level (Beginner / Intermediate / Advanced).
- Tapping "Finish" saves the assessment and navigates to the Dashboard.

### How it benefits users
- Eliminates guesswork — the app knows the user before recommending anything.
- All future workout prescriptions (sets, reps, rest) are derived from this data automatically.

### Connections to other features
- **Workout Generator** uses fitness goal, fitness level, and workout preference to generate the plan.
- **BMI Calculator** uses height and weight from this step.
- **Profile** stores all this data and allows it to be updated later (changing values immediately re-normalizes future workout plans).

---

## 4. Feature 3: Dashboard & Workout Schedule Calendar

### What it does
The Dashboard is the home screen of SyncroFit. It displays:
- A **weekly calendar** showing scheduled workout days and completion status.
- A **workout card** for the selected day that reveals the assigned workout.
- A **weekly progress counter** (workouts completed vs. planned).

### How it works
- Scheduled workout days appear as **outlined dates** on the calendar.
- Completed workout days are marked with a **dot indicator**.
- Tapping a date selects it (highlighted with a filled circle) and shows its workout card below.
- The calendar is driven by the `scheduledWorkoutsProvider` — the same source used by the recommendation engine — so outlined days always match the actual plan.
- Weekly progress counts **completed** workouts against the actual number of **scheduled days**, preventing the completed count from ever exceeding the plan.

### How it benefits users
- Gives an at-a-glance view of the week's plan and how much has been done.
- Makes schedule discovery easy — users don't need to navigate elsewhere to know what to do today.

### Connections to other features
- Tapping a workout card on the Dashboard navigates to **Workout Detail**.
- The calendar uses the same data source as the **Workout Generator**, keeping the UI and backend in sync.
- Completion dots are updated immediately when a workout is finished in the **Active Workout** screen.

---

## 5. Feature 4: Workout Generator (Personalized Recommendations)

### What it does
Generates a personalized **3-day-per-week workout schedule** tailored to the user's fitness level, fitness goal, and training location. This is the core intelligence of SyncroFit.

### How it works
1. User navigates to the **Workout Generator** screen (accessible from the Dashboard).
2. Generator reads the user's profile for defaults (fitness level, goal, workout preference).
3. User can override these for a one-off plan without changing their profile permanently:
   - Fitness Level (Beginner / Intermediate / Advanced)
   - Fitness Goal (Lose Weight / Build Muscle / Maintain Fitness / Improve Endurance)
   - Training Location (Gym / Home / Outdoor)
   - Optional checkbox: "Save these options to my profile."
4. User can optionally select **Focus Muscles** (e.g., Chest, Back, Core) — the engine scores exercises for those muscles higher. Leaving all off produces a balanced full-body plan.
5. User can flag specific exercises as **Preferred** (the engine tries to include them) or **Excluded** (the engine never picks them). The picker only shows exercises eligible for the selected location and fitness level.
6. User taps **"Generate Workout"** — the backend runs the recommendation engine.
7. A **draft plan** appears for review (workout name, day, estimated duration, exercises with sets/reps).
8. User can **Regenerate** (tries again) or **Accept Plan** to commit it to the schedule.
9. Only after "Accept Plan" does the plan become the active schedule and trigger local notification scheduling.

### The Recommendation Engine (Rule-Based)
The engine follows a documented prescription policy:

| Fitness Level | Working Sets per Exercise |
|---|---|
| Beginner | 2 sets |
| Intermediate | 3 sets |
| Advanced | 3 sets (4 only for one designated priority lift) |

| Goal / Exercise Type | Reps or Duration | Rest |
|---|---|---|
| Build Muscle (compound) | 6–12 reps | 120–180 seconds |
| Build Muscle (isolation/machine) | 10–20 reps | 60–120 seconds |
| Lose Weight / Maintain Fitness | 8–12 reps | 90–120 seconds |
| Improve Endurance | 12–20 reps | 60–90 seconds |
| Timed / Isometric | 20–45 seconds | 60–120 seconds |

**Location-based filtering:**
- Home/Outdoor plans include **bodyweight-only** exercises (no equipment assumed).
- Gym plans can include barbell, cable, dumbbell, and machine exercises.

**Redundancy protection:**
- At most 2 exercises with the same primary muscle and movement pattern per session.
- Max 10 direct working sets per muscle per session.

### How it benefits users
- No guesswork — the app prescribes exactly what to do, for how long, and how many times.
- Respects the user's location (no gym exercises prescribed to home users).
- Prevents "junk volume" by capping sets per muscle using evidence-aligned guidelines.

### Connections to other features
- Generated plan becomes the **Dashboard calendar** schedule.
- Each workout in the plan is navigable from the Dashboard to **Workout Detail → Active Workout**.
- **Workout Customization** is available after a plan is accepted.

---

## 6. Feature 5: Workout Customization

### What it does
Allows users to modify an already-accepted recommended workout by adding, removing, or reordering exercises — without manually entering sets, reps, or rest values (the system handles that).

### How it works
1. From a **Workout Detail** screen, user taps **"Customize Workout."**
2. The customization screen shows the current ordered exercise list.
3. User can:
   - **Add** an exercise from the library (as long as it's not already in the workout and doesn't violate muscle-volume limits).
   - **Remove** an exercise (at least one must remain).
   - **Reorder** exercises by dragging.
4. The user saves changes — the backend re-derives all prescription values (sets, reps, rest) from the user's current fitness level and goal.
5. The client cannot submit custom sets/reps/rest values — the server rejects them.

**Online-only operation:** Customization requires an active internet connection because the backend must validate muscle limits and recalculate prescriptions. If offline, the app explains this and preserves the existing cached plan.

**Validation errors are descriptive:** If an exercise would violate muscle-volume limits (e.g., too many pushing exercises), the server returns a specific, actionable message like *"This workout already has 2 push exercises targeting the chest."*

### How it benefits users
- Gives users agency over their plan while preventing unsafe, unbalanced, or ineffective configurations.
- All science-based safeguards remain in place even when the user customizes.

### Connections to other features
- After saving, the **Dashboard**, **Workout Detail**, **Active Workout**, and **Progress** all reflect the updated plan immediately.
- Changing fitness level or goal in **Profile** re-normalizes all future recommended workouts through the same policy.

---

## 7. Feature 6: Active Workout & Rest Timer

### What it does
Guides users through a workout in real time — set by set — with an automatic countdown rest timer and completion tracking.

### How it works
1. User taps **"Start Workout"** from a Workout Detail screen.
2. The **Active Workout** screen shows the exercise list with sets and reps/duration.
3. User works through each set and marks it as done.
4. After every completed set (except the last set of the final exercise), the **Rest Timer** screen appears automatically with the prescribed countdown (derived from the workout's `rest_seconds` field — not a fixed value).
5. When the timer ends, the next set/exercise is queued automatically.
6. When the user taps **"Finish Workout"**, the app evaluates the session:
   - **Zero exercises logged** → prompts "Discard Session" or "Resume Workout."
   - **Partially completed** → prompts "Finish Anyway" or "Resume Workout."
   - **Fully completed** → transitions to the **Workout Summary** screen.
7. The **Workout Summary** displays completed exercises, duration, and congratulatory feedback.

### How it benefits users
- Removes the need to watch a clock or count rest time manually.
- Rest periods are scientifically calibrated to the user's goal and fitness level (not a universal 30 or 60 seconds).
- Prevents junk data (zero-exercise sessions) from polluting the user's workout history and weekly statistics.

### Connections to other features
- Completing a workout updates the **Dashboard** weekly counter and completion dots.
- The workout history feeds into the **Progress Summary** (Recent Workouts).
- **Rest timer duration** is derived from the prescription set by the **Workout Generator** or **Customization** feature.

---

## 8. Feature 7: BMI Calculator & Progress Summary

### What it does
The Progress screen has two main areas:
1. **BMI Card** — displays the user's current BMI and category in real time.
2. **Recent Workouts / Weekly Statistics** — shows completed workout history and a weekly bar chart.

### How the BMI Calculator works
- BMI is calculated as: `weight (kg) ÷ (height (cm) ÷ 100)²`
- Result is rounded to one decimal place.
- Category labels are displayed:
  - Underweight: below 18.5
  - Healthy: 18.5 – 24.9
  - Overweight: 25.0 – 29.9
  - Obesity: 30.0 and above
- **No profile?** — An empty state with a "Set Up Profile" button is shown instead of a number.
- **Updates live** — changing height or weight in Profile recalculates BMI immediately without needing to restart the app.
- A disclaimer clarifies that BMI categories are informational and not medical advice.

### How it benefits users
- Users don't need to calculate their own BMI or re-enter values.
- Changes to profile weight (e.g., after logging a progress photo) are reflected immediately.

### Connections to other features
- BMI source data comes from **Profile** (height and weight fields).
- The Progress screen also hosts the **Log Progress** action (Feature 8).
- Workout history shown here comes from the **Active Workout** completion flow.

---

## 9. Feature 8: Progress Logging (Photo & Weight Logs)

### What it does
Allows users to create **private, dated progress entries** containing a title, description, current weight, and a photo (from gallery or camera). Entries are displayed in a timeline grouped by month/year.

### How it works
1. User taps **"Log Progress"** on the Progress screen.
2. A form appears with:
   - **Title** (required, max 100 characters)
   - **Description** (required, max 1,000 characters)
   - **Current Weight in kg** (required, 20–500 kg range)
   - **Photo** — selected from gallery or captured with camera (JPEG, PNG, or WebP; max 5 MB; max 4096×4096 pixels)
3. A preview of the selected photo is shown before saving.
4. Upload progress is displayed. Duplicate submissions are prevented. Retry is available if the upload fails.
5. After a successful save, the log appears at the top of the timeline.
6. Logs are grouped into month/year sections (e.g., *November 2026*, *October 2026*) in descending order.
7. Tapping a log opens a **Detail View**. Users can delete their own logs with a confirmation step.

**Privacy:** Logs are private to the authenticated user. No other user can view or delete them. Images are stored using private, authorized delivery.

**Progress logs do not automatically update profile weight.** They are an independent visual record.

### How it benefits users
- Visual progress (before/after photos) is one of the strongest motivators for exercise adherence.
- Grouping by month makes it easy to see transformation over time.
- Camera capture is built-in — no need to switch apps.

### Connections to other features
- The "Log Progress" entry point is on the **Progress** screen alongside the BMI Card.
- If a user wants to update their profile weight after logging, they can do so separately via **Profile Edit**.

---

## 10. Feature 9: Community Feed (Social Module)

### What it does
A simple social feed where authenticated users can publish posts (text and/or photos), like/unlike posts, and comment.

### How it works

**Feed:**
- Displays the latest posts from all users in reverse-chronological order.
- Each post shows: author username (not real name), text content, photo(s), like count, comment count, and timestamp.
- Feed paginates automatically as the user scrolls (15 posts per page).

**Creating a Post:**
- User taps a compose button and enters text (max 2,000 characters).
- Optionally attaches up to **4 photos** (JPEG, PNG, or WebP; max 8 MB each; max 4096×4096 px).
- A preview is shown before publishing.
- Upload progress is displayed. Invalid/oversized files are rejected by both client and server.

**Likes:**
- Users can like/unlike any post with a single tap.
- One like per user per post is enforced by the database (idempotent — rapid taps won't create duplicates).
- Like counts update optimistically with rollback if the server request fails.

**Comments:**
- Users can add comments (max 500 characters) and delete their own.
- Comments are displayed oldest-first (chronological reading order) within a post detail view.

**Deleting:**
- Users can delete their own posts and comments with a confirmation prompt.
- No user can delete content owned by someone else — enforced server-side.

**Intentionally excluded:** Reposts, shares, direct messages, following, groups, and real-time chat are out of scope.

### How it benefits users
- Creates a motivational space where gym members and fitness enthusiasts can share achievements and encourage each other.
- Using usernames (not real names) provides privacy.
- Simple scope keeps the feature usable and distraction-free.

### Connections to other features
- Community uses **Login** identity — posts and comments are attributed to the authenticated user's username (set at registration, customizable in Profile).
- Progress photos logged in Feature 8 remain private; they are **not** auto-published to Community. Sharing to Community is a deliberate separate action.

---

## 11. Feature 10: Exercise Library

### What it does
A browsable catalog of all 31 exercises available in SyncroFit, with details, illustrations, and instructions for each.

### How it works
- Users can browse and search exercises.
- Each exercise entry includes: name, target muscles (primary and secondary), difficulty level, required equipment, training locations, fitness goals it serves, and instructional illustrations.
- The library is filterable by muscle group, location, and goal to help users explore.

**The Exercise Catalog (31 exercises):**

| Category | Examples | Level |
|---|---|---|
| Bodyweight & Plyometrics | Jumping Jacks, High Knees, Mountain Climbers, Burpees | Beginner – Advanced |
| Dumbbell | Bicep Curl, Single-Arm Row, Overhead Press, Romanian Deadlift | Beginner – Advanced |
| Barbell | Bench Press, Back Squat, Bent-Over Row, Deadlift | Intermediate – Advanced |
| Cable & Machine | Tricep Pushdown, Chest Fly, Leg Press, Cable Woodchop | Beginner – Intermediate |

### How it benefits users
- Beginners can learn what an exercise is and how to do it before encountering it in a workout.
- Users researching exercises to add during Workout Customization can preview them here first.

### Connections to other features
- Exercise data powers the **Workout Generator** (scoring, filtering, eligibility).
- **Workout Customization** uses the exercise library picker to add exercises.
- The **Active Workout** screen can link to exercise detail for in-session reference.

---

## 12. Feature 11: Profile Management

### What it does
Stores and manages the user's fitness identity — the data that personalizes the entire app.

### Profile fields include:
- First name, last name, username
- Height (cm), Weight (kg)
- Age, Gender, Activity Level
- Fitness Goal (Lose Weight / Build Muscle / Maintain Fitness / Improve Endurance)
- Fitness Level (Beginner / Intermediate / Advanced)
- Workout Preference (Gym / Home / Outdoor)
- Low-Impact Only toggle (restricts exercises to low-impact options — useful for injury management)

### How it works
- **Profile Setup** (`/profile-setup`) is a guided form triggered when no profile exists.
- **Profile Edit** (`/settings/profile`) allows updating any field after initial setup.
- **Profile View** displays the current profile at a glance.

**Effect of changes:**
- Updating height or weight → **BMI recalculates immediately**.
- Updating fitness level or fitness goal → **all non-completed recommended workouts are re-normalized** through the prescription policy (completed workout history is never rewritten).
- Updating username → the new username appears on all future Community posts and comments.

### How it benefits users
- One profile update cascades correctly through the entire system without needing to regenerate manually.
- All data is scoped to the authenticated user — no data leaks between accounts.

### Connections to other features
- Profile data is the input to the **Workout Generator** and **BMI Calculator**.
- Username is the public identity in **Community**.
- The **Settings** screen provides the navigation path to profile editing.

---

## 13. Feature 12: Settings

### What it does
Provides access to account management and app configuration options.

### Settings options:

| Option | What it does |
|---|---|
| My Profile | Navigates to Profile Edit screen |
| App Notifications | Opens Android system notification settings for SyncroFit |
| Send Test Workout Reminder | Immediately fires a test notification to verify it's working |
| Change Password | Navigates to the change-password form |
| Privacy Policy | Displays RA 10173 (Data Privacy Act) compliance information |
| Dark Mode toggle | Switches the app theme to dark/light; persists across sessions |
| Open-Source Licenses | Displays exercise illustration attributions (CC BY-SA 4.0) |
| Sign Out | Prompts confirmation, then clears session and returns to Login |

### How it benefits users
- All account and app preferences are in one accessible place.
- Dark mode respects personal visual preference and reduces eye strain.
- The privacy policy and open-source licenses fulfill transparency obligations.

---

## 14. Feature 13: Workout Reminders (Local Notifications)

### What it does
Schedules automatic local Android notifications at **8:00 AM** on each of the user's planned workout days, reminding them to complete their scheduled workout.

### How it works
- When a workout plan is accepted, the app schedules recurring reminders for each day in the plan (e.g., Monday, Wednesday, Friday).
- Reminders are delivered using **inexact timing** — no exact-alarm permission is required, which avoids an additional Android permission prompt.
- Tapping a notification opens the app and navigates directly to the matching workout for that day.
- Reminders are **restored automatically after device reboot or app update** — the user doesn't need to regenerate their plan for reminders to continue.
- Users can mute or manage notifications through Android's standard system notification settings (accessible via Settings → App Notifications).
- Settings include a **"Send Test Workout Reminder"** option to verify that notifications are working on the user's device.

### How it benefits users
- Reduces reliance on the user's memory to maintain workout consistency.
- Works entirely **offline** — no internet connection or backend push notification service needed.
- Gives the user control: notifications can be silenced in phone settings without changing anything in the app.

### Connections to other features
- Notification schedule is set when the **Workout Generator** plan is accepted.
- Tapping a notification links directly to the relevant **Workout Detail** screen for that day.

---

## 15. How Features Connect (Cross-Feature Relationships)

The diagram below describes the data flow and navigation relationships between all major features:

```
[Registration / Login]
        ↓
[Initial Assessment (3 steps)]
        ↓
[Dashboard + Calendar]
   ├──→ [Workout Detail]
   │         ├──→ [Active Workout → Rest Timer → Workout Summary]
   │         └──→ [Workout Customization]
   └──→ [Workout Generator]
              └──→ (Accepted Plan updates Dashboard + schedules Notifications)

[Profile]
   └──→ Drives BMI Calculator, Workout Generator, Prescription Policy, Community Username

[Progress Screen]
   ├──→ [BMI Card] (live from Profile)
   ├──→ [Recent Workouts + Weekly Stats] (from Active Workout completions)
   └──→ [Log Progress → Progress Log Detail / Delete]

[Community Feed]
   └──→ [Post Detail → Likes / Comments / Delete]

[Exercise Library]
   └──→ Referenced by Workout Generator, Customization, Active Workout

[Settings]
   ├──→ Profile Edit (cascades to BMI + Workout normalization)
   ├──→ Change Password
   ├──→ Notification Settings
   └──→ Sign Out (clears all user-scoped state)
```

**Key cascade relationships:**
- Updating **Profile weight/height** → BMI recalculates live on the Progress screen.
- Updating **fitness level or goal** → all pending/recommended workout prescriptions (sets, reps, rest) are re-normalized automatically.
- Accepting a **generated plan** → Dashboard calendar, workout cards, and local notification schedule all update.
- Completing a **workout** → Dashboard completion dots, weekly stats counter, and Recent Workouts list all update.

---

## 16. Technology Stack Summary

| Layer | Technology |
|---|---|
| Mobile client | Flutter (Dart) targeting Android |
| State management | Riverpod (Provider pattern) |
| Navigation | GoRouter |
| Backend API | Laravel (PHP) with Sanctum API token authentication |
| Database | MySQL (production) via Laravel Eloquent ORM |
| Local storage (offline) | SQLite via `drift` (local caching of profiles, workouts) |
| Media storage | Private filesystem (dev) / S3-compatible object storage (production) |
| Password reset email | Brevo HTTPS API (avoids SMTP port restrictions) |
| Local notifications | Android local notifications (inexact alarm, no FCM required) |
| Exercise illustrations | Workout Guide by Bryl Lim (CC BY-SA 4.0); RepDB supplementary artwork |

---

## 17. Scope & Limitations for Presentation

### What is in scope and working:
- ✅ Android-only application (no iOS, web, or desktop)
- ✅ Rule-based recommendation engine (no AI/ML)
- ✅ BMI calculator and category display
- ✅ Personalized workout generation (3 days/week)
- ✅ Workout customization (add/remove/reorder exercises)
- ✅ Active workout with rest timer
- ✅ Progress logging with photos
- ✅ Community feed (text + up to 4 photos, likes, comments)
- ✅ Local Android notifications for workout reminders
- ✅ Offline support for cached profiles and workout data
- ✅ Password recovery via email
- ✅ Dark mode
- ✅ Privacy Policy (RA 10173)

### What is explicitly out of scope:
- ❌ iOS, web, Windows, macOS builds
- ❌ Real-time trainer interaction or live coaching
- ❌ Wearable device integration
- ❌ AI, machine learning, or deep learning
- ❌ Community reposts, shares, DMs, groups, stories, or real-time chat
- ❌ Automatic publication of private progress logs to Community
- ❌ User-defined sets, reps, duration, or rest values (server controls these)
- ❌ Medical diagnosis or personalized medical advice based on BMI

### Evaluation framework:
The system is evaluated against **ISO/IEC 25010:2023** product quality characteristics:
- Functional Suitability
- Performance Efficiency
- Interaction Capability
- Reliability
- Security

---

*SyncroFit © 2026 | Gecolea, John Carlo E. · Lopez, Gian Simon P. · Morillo, Lexmar F.*
*Department of Computing and Informatics — City College of Calamba*
