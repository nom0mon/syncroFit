# SyncroFit UX Guidelines & Specifications

This document outlines the user experience (UX) and interaction flows for managing workout logs, handling session completions, and balancing expert-validated recommendations with user customization within the SyncroFit app.

## 1. Activity Deletion (Long-Press Multi-Select)

**Objective:** Allow users to efficiently clean up accidental, empty, or unwanted workout logs without cluttering the default UI with delete icons.

### Interaction Flow
1. **Trigger:** User long-presses any card within the "Recent Workouts" list. App provides haptic feedback and enters "Selection Mode."
2. **UI State:** Top bar changes to a context menu showing selected count (e.g., "1 Selected") and a "Select All" button. Checkboxes appear on cards. A sticky bottom bar appears with a "Delete" button.
3. **Confirmation:** Tapping "Delete" prompts a confirmation dialog. Upon confirmation, items are removed, and the "Weekly Statistics" chart recalculates immediately.

## 2. Workout Completion Flow

**Objective:** Prevent the creation of "junk" data and ensure that the "Workout Completed" screen genuinely reflects a valid effort.

### Evaluation Rules on pressing "Finish Workout"
* **Zero (0) Exercises Logged:** Intercept finish command. Show prompt: "You haven't logged any exercises yet. Do you want to discard this session?" (Actions: Discard / Resume).
* **Partially Completed Routine:** Intercept finish command. Show prompt: "You still have uncompleted exercises left. Are you sure you want to finish?" (Actions: Finish Anyway / Resume).
* **Fully Completed Routine:** Seamlessly transition to the "Workout Completed" screen. Save to Recent Workouts and update Weekly Statistics.

## 3. Workout Customization & Coach Baselines

**Objective:** Balance the integrity of coach-validated workout recommendations with the user's need for daily flexibility and auto-regulation.

### Core Philosophy: "Intelligent Baselines"
* **Populating the Baseline:** The app defaults to the coach's validated parameters (e.g., 3 sets, 10 reps, 150s rest).
* **"Customize Workout":** Users can modify exercises, volume (sets/reps), and rest timers based on daily fatigue or time constraints.
* **Restoring the Baseline:** Include a "Restore Recommended Plan" button to revert to the coach's setup.
* **Visual Indicators:** Display a "Customized" tag if the user deviates from the original recommendation.

## 4. Countermeasures for Skipped/Empty Workouts

**Objective:** Implement strict guardrails to prevent users from skipping all exercises and triggering a false "Workout Completed" state, which corrupts the Weekly Statistics chart.

### Recommended Implementation Steps

#### A. Dynamic Action Button UI
Modify the primary action button on the active workout screen based on the session's state:
* **State: 0 Sets Logged:** The button label should read **"Cancel Session"** or **"Discard Workout"** (using a neutral or destructive visual style).
* **State: ≥ 1 Set Logged:** The button label updates to **"Finish Workout"** (using the primary accent color).

#### B. The Intercept & Confirm Modal
If a user taps the finish/cancel button while `totalCompletedSets == 0`, strictly block navigation to the success screen.
* **Display Modal:** *"No Exercises Logged. You haven't completed any sets in this session. Nothing will be saved to your workout history."*
* **Actions:** `[ Discard Workout ]` | `[ Resume Workout ]`

#### C. Silent Auto-Discard on Final Skip
If the user utilizes a "Skip" function to bypass every single exercise in the program and reaches the end of the stack with zero data:
* **Action:** Immediately purge the active workout state.
* **Routing:** Navigate the user back to the Home or Progress screen. **Do not** show confetti or the "Workout Completed" screen.
* **Feedback:** Display a transient Toast notification at the bottom of the screen: *ℹ️ Workout discarded — no exercises were completed.*

#### D. Backend & Data Layer Guardrails
Enforce a validation rule before writing to the database or processing the Weekly Statistics chart data:
* `IF session.completedSets == 0 THEN Drop Payload`
* This ensures that even if a frontend bug allows an empty session to be submitted, the database will reject the ghost log (e.g., 00:01 duration, 0 exercises), keeping user progress metrics perfectly accurate.