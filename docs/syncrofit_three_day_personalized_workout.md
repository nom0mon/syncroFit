# SyncroFit: Three-Day Personalized Workout Example

## Overview

This example demonstrates how SyncroFit could distribute a three-day weekly workout for a user who selects **Chest** and **Back** as focus muscles.

The selected muscle groups receive additional emphasis, while other muscle groups are still trained to maintain balanced coverage.

### User Preferences

- **Fitness Level:** Intermediate
- **Fitness Goal:** Muscle Building
- **Focus Muscles:** Chest, Back
- **Workout Frequency:** 3 days per week
- **Example Schedule:** Monday, Wednesday, Friday

> This is an illustrative workout plan. Exercise selection, sets, repetitions, and difficulty should be adjusted according to the user's capacity, available equipment, and recovery needs.

---

## Day 1 – Chest and Back Emphasis

**Priority muscle groups:** Chest and Back

| Exercise | Target Muscles | Sets × Reps |
|---|---|---:|
| Push-Up | Chest, Triceps | 3 × 10 |
| Dumbbell Bench Press | Chest, Shoulders, Triceps | 3 × 10 |
| Dumbbell Single-Arm Row | Back, Biceps | 3 × 10 |
| Dumbbell Overhead Press | Shoulders, Triceps | 2 × 10 |
| Plank | Core | 3 × 30 seconds |

## Day 2 – Legs and Supporting Muscles

**Priority:** Lower body and supporting muscle groups

| Exercise | Target Muscles | Sets × Reps |
|---|---|---:|
| Bodyweight Squat | Quadriceps, Glutes | 3 × 12 |
| Dumbbell Romanian Deadlift | Hamstrings, Glutes | 3 × 10 |
| Walking Lunge | Quadriceps, Glutes | 2 × 10 |
| Dumbbell Bicep Curl | Biceps | 2 × 12 |
| Plank | Core | 3 × 30 seconds |

## Day 3 – Chest and Back Emphasis

**Priority muscle groups:** Chest and Back

| Exercise | Target Muscles | Sets × Reps |
|---|---|---:|
| Dumbbell Bench Press | Chest, Triceps | 3 × 10 |
| Dumbbell Single-Arm Row | Back, Biceps | 3 × 10 |
| Push-Up | Chest, Triceps | 2 × 10 |
| Dumbbell Romanian Deadlift | Hamstrings, Glutes, Back | 2 × 10 |
| Dumbbell Overhead Press | Shoulders, Triceps | 2 × 10 |
| Hanging Knee Raise | Core | 2 × 12 |

---

## Weekly Muscle Distribution

| Muscle Group | Weekly Exercise Selections | Classification |
|---|---:|---|
| Chest | 3 | Priority |
| Back | 3 | Priority |
| Shoulders | 2 | Supporting |
| Biceps | 2 | Supporting |
| Triceps | Multiple compound exercises | Supporting |
| Legs | 3 | Supporting |
| Core | 3 | Supporting |

**Note:** These counts represent exercise selections, not total training volume. Compound exercises may train multiple muscle groups simultaneously.

---

## Recommended SyncroFit Generation Workflow

### Step 1 – Read User Preferences

The generator receives the user's:

- Fitness level
- Fitness goal
- Selected focus muscles
- Available workout days
- Workout location and available equipment
- Preferred and excluded exercises

### Step 2 – Filter Eligible Exercises

Filter the exercise database using the user's fitness level, goal, location, equipment availability, and exercise exclusions.

### Step 3 – Apply Muscle Prioritization

Give higher selection priority to exercises that target the user's selected focus muscles.

A possible scoring approach:

| Condition | Score Bonus |
|---|---:|
| Explicitly preferred exercise | +100 |
| Fitness goal match | +30 |
| Primary muscle matches a focus muscle | +40 |
| Secondary muscle matches a focus muscle | +20 |

These values are proposed starting weights and should be validated through testing. Scoring must not override fitness-level eligibility, equipment requirements, or excluded exercises.

### Step 4 – Distribute Exercises Across Workout Days

Distribute selected exercises across the available days while considering:

- Additional emphasis for selected focus muscles
- Adequate coverage of supporting muscle groups
- Movement-pattern requirements
- Exercise variety
- Appropriate recovery between demanding sessions

### Step 5 – Generate the Personalized Workout

Present the resulting weekly plan with exercises, target muscles, sets, repetitions, and scheduled workout days.

---

## Recommended Workout Generation Rules

1. **Priority muscles:** Selected muscle groups should receive greater weekly training emphasis than non-selected groups.
2. **Supporting muscles:** Non-selected muscle groups should still receive appropriate exercise coverage.
3. **Recovery:** Avoid placing demanding exercises for the same muscle groups on consecutive training days without sufficient recovery.
4. **No forced inclusion:** Do not force every muscle group into every workout session.
5. **Preference handling:** Preferred exercises should be prioritized, while excluded exercises must never be selected.
6. **Eligibility:** Focus-muscle prioritization must not override fitness-level, location, or equipment restrictions.
7. **Balanced generation:** The number of available workout days should influence how exercises are distributed.

## Key Design Recommendation

Implement focus muscles as a **prioritization mechanism rather than a hard filter**.

This allows SyncroFit to give users greater control over the muscle groups they want to emphasize without excluding exercises that support a balanced workout.

The generator should remain deterministic and rule-based. No AI, machine learning, or deep learning is required for this approach.
