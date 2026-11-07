# SyncroFit UX Guidelines & Specifications

This document outlines the user experience (UX) and interaction flows for managing workout logs and handling session completions within the SyncroFit app.

---

## 1. Activity Deletion (Long-Press Multi-Select)

**Objective:** Allow users to efficiently clean up accidental, empty, or unwanted workout logs (e.g., sessions with 00:01 duration and 0 exercises) without cluttering the default UI with delete icons.

### Interaction Flow

1. **Trigger (Enter Selection Mode):**
   * **Action:** User long-presses any card within the "Recent Workouts" list.
   * **Response:** Provide haptic feedback (short vibration). The selected card is immediately marked as checked, and the app transitions into "Selection Mode."

2. **Selection Mode UI State:**
   * **Header/Top Bar:** Replaces the standard screen title ("Progress") with a context menu showing:
     * A "Cancel" button (or 'X' icon) on the left.
     * A dynamic count of selected items (e.g., "1 Selected", "3 Selected").
     * A "Select All" button on the right.
   * **List Items (Cards):** A selection indicator (e.g., a circular checkbox) smoothly animates into view on either the left or right edge of every Recent Workout card.
   * **Tap Behavior:** While in Selection Mode, single-tapping a card toggles its selection status instead of navigating to the workout details. 
   * **Action Bar:** A sticky bottom bar slides up containing a prominent "Delete" button.

3. **Confirmation & Execution:**
   * **Action:** User taps "Delete".
   * **Response:** Trigger a confirmation dialog to prevent accidental data loss:
     * *Title:* "Delete Workouts?"
     * *Message:* "Are you sure you want to delete [X] workout logs? Your Weekly Statistics will be updated. This cannot be undone."
     * *Actions:* "Cancel" / "Delete"
   * **Completion:** Upon confirmation, the deleted items animate out of the list, Selection Mode automatically closes, and the "Weekly Statistics" chart recalculates immediately.

### Edge Cases & Navigation Rules
* **Empty Selection:** If the user unchecks all previously selected items, automatically exit Selection Mode and return to the default state.
* **Hardware/System Back Button:** Pressing the back button while in Selection Mode should dismiss Selection Mode, *not* navigate to the previous app screen.

---

## 2. Workout Completion Flow

**Objective:** Prevent the creation of "junk" data (zero-exercise sessions) and ensure that the "Workout Completed" screen genuinely reflects a valid effort, maintaining the integrity of the user's statistics.

### Evaluation Rules on pressing "Finish Workout"

When a user taps "Finish" or "End" on an active workout session, the app must evaluate the session data before directing them to the "Workout Completed" screen.

#### Scenario A: Zero (0) Exercises Logged
* **Condition:** The user has not logged a single set, rep, or checked off any exercise.
* **Action:** Intercept the finish command. Do **not** go to the completion screen.
* **Prompt:** Display an action sheet or modal.
  * *Message:* "You haven't logged any exercises yet. Do you want to discard this session?"
  * *Actions:* 
    * **"Discard Session"** (Destructive action - deletes the timer/session entirely, does not save to Recent Workouts or update stats).
    * **"Resume Workout"** (Returns user to the active timer/logging screen).

#### Scenario B: Partially Completed Routine
* **Condition:** The user is following a pre-built program (e.g., 5 exercises planned) but has only logged data for a portion of them (e.g., 2 exercises).
* **Action:** Intercept the finish command to confirm intent.
* **Prompt:** 
  * *Message:* "You still have uncompleted exercises left in this program. Are you sure you want to finish?"
  * *Actions:*
    * **"Finish Anyway"** (Proceeds to completion screen. Saves the workout with only the completed data. Marks status as 'Partially Completed' internally).
    * **"Resume Workout"** (Returns user to the active screen).

#### Scenario C: Valid / Fully Completed Routine
* **Condition:** The user has completed all planned exercises, OR (in a freestyle workout) has logged at least one valid exercise with sets/reps.
* **Action:** Seamlessly transition to the "Workout Completed" success screen. 
* **Data Handling:** Save to "Recent Workouts" and increment the "Weekly Statistics" chart.