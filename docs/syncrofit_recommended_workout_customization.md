# Workout Customization & Coach Baselines

**Objective:** Balance the integrity of gym-owner/coach-validated workout recommendations with the user's need for daily flexibility, auto-regulation, and real-world constraints.

### Core Philosophy: "Intelligent Baselines"
Expert-validated sets must act as the default *baseline*, not a rigid constraint. Users must have the autonomy to adjust sets, reps, and rest times because:
1. **Auto-Regulation:** A user's physical readiness fluctuates daily. They need to adjust reps based on fatigue or unexpected strength to maintain accurate progressive overload.
2. **Real-World Constraints:** Gym equipment wait times or limited personal schedules may require a user to shorten rest periods (e.g., from 150s to 90s) or skip a set.

### Interaction & UI Rules

1. **Populating the Baseline:**
   * When a user selects a recommended workout (e.g., "Upper A"), the app populates the sheet with the coach's exact validated parameters (e.g., 3 sets, 10 reps, 150s rest).

2. **"Customize Workout" Capabilities:**
   * Tapping "Customize Workout" opens an edit overlay allowing full modification of:
     * **Exercises:** Add, remove, or reorder movements.
     * **Volume:** Add/remove sets and adjust the target rep count per set.
     * **Rest Timers:** Modify duration per exercise (with quick-picks like 60s, 90s, 120s, 150s).

3. **Restoring the Baseline:**
   * Include a "Restore Recommended Plan" (or similar reset icon) in the customization header. This allows users to undo their tweaks and instantly revert to the coach's validated setup.

4. **Visual Indicators (Tags):**
   * If a user modifies the coach's baseline, display a subtle "Customized" chip/tag on the Workout Detail screen to indicate that the current targets have deviated from the original recommendation.