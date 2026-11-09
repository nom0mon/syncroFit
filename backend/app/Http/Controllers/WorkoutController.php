<?php

namespace App\Http\Controllers;

use App\Models\Workout;
use App\Services\RecommendationEngine;
use App\Services\WorkoutPrescriptionPolicy;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class WorkoutController extends Controller
{
    /**
     * List authenticated user's workouts, optionally filter by is_generated.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Workout::where('user_id', $request->user()->id)
            ->where('is_accepted', true);

        if ($request->has('is_generated')) {
            $query->where('is_generated', filter_var($request->query('is_generated'), FILTER_VALIDATE_BOOLEAN));
        }

        $workouts = $query->orderBy('created_at', 'desc')->get();

        return response()->json(['success' => true, 'data' => $workouts]);
    }

    /**
     * Create a user-defined workout.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'day_of_week' => 'nullable|string',
            'estimated_duration_minutes' => 'nullable|integer|min:1',
            'exercises' => 'required|array',
            'exercises.*.exercise_id' => 'required|integer|exists:exercises,id',
            'exercises.*.sets' => 'required|integer|min:1|max:20',
            'exercises.*.reps' => 'required|integer|min:1|max:100',
            'exercises.*.duration_seconds' => 'required|integer|min:0',
            'exercises.*.order' => 'required|integer|min:1',
        ]);

        $workout = Workout::create([
            'user_id' => $request->user()->id,
            'name' => $validated['name'],
            'day_of_week' => $validated['day_of_week'] ?? null,
            'estimated_duration_minutes' => $validated['estimated_duration_minutes'] ?? null,
            'exercises' => $validated['exercises'],
            'is_generated' => false,
        ]);

        return response()->json(['success' => true, 'data' => $workout], 201);
    }

    /**
     * Generate workouts via the RecommendationEngine and store with is_generated=true.
     */
    public function generate(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->profile;

        if (!$profile) {
            return response()->json([
                'success' => false,
                'message' => 'Please set up your profile before generating recommendations.',
            ], 422);
        }

        $validated = $request->validate([
            'included_exercises' => 'nullable|array',
            'included_exercises.*' => 'integer',
            'excluded_exercises' => 'nullable|array',
            'excluded_exercises.*' => 'integer',
            'focus_muscles' => 'nullable|array',
            'focus_muscles.*' => 'string',
            'fitness_level' => 'nullable|in:beginner,intermediate,advanced',
            'goal' => 'nullable|in:lose_weight,build_muscle,stay_fit,increase_stamina',
            'workout_preference' => 'nullable|in:home,gym,outdoor',
            'low_impact_only' => 'nullable|boolean',
            'save_options_to_profile' => 'sometimes|boolean',
        ]);

        $included = $validated['included_exercises'] ?? [];
        $excluded = $validated['excluded_exercises'] ?? [];
        $focusMuscles = $validated['focus_muscles'] ?? [];
        $overrides = array_filter([
            'fitness_level' => $validated['fitness_level'] ?? null,
            'goal' => $validated['goal'] ?? null,
            'workout_preference' => $validated['workout_preference'] ?? null,
            'low_impact_only' => isset($validated['low_impact_only'])
                ? (bool) $validated['low_impact_only']
                : null,
        ], fn ($value) => $value !== null);

        // --- BMI-based goal safety guard ---
        // Resolve the effective goal (override or profile) and validate it
        // against the user's current BMI so clinically unsafe combinations
        // are rejected before the engine runs.
        $effectiveGoal = $overrides['goal'] ?? $profile->goal;
        $bmiForGuard = ($profile->weight_kg > 0 && $profile->height_cm > 0)
            ? (float) $profile->weight_kg / pow((float) $profile->height_cm / 100, 2)
            : null;

        if ($bmiForGuard !== null && $effectiveGoal !== null) {
            $allowedGoals = $this->allowedGoalsForBmi($bmiForGuard);
            if (!in_array($effectiveGoal, $allowedGoals, true)) {
                return response()->json([
                    'success' => false,
                    'message' => 'The selected fitness goal is not available for your current BMI category.',
                    'errors' => [
                        'goal' => [
                            'Your BMI category restricts the available fitness goals. Please choose from: '
                            . implode(', ', array_map(fn ($g) => str_replace('_', ' ', $g), $allowedGoals)) . '.',
                        ],
                    ],
                ], 422);
            }
        }

        if (($validated['save_options_to_profile'] ?? false) && $overrides !== []) {
            $profile->update($overrides);
            $profile->refresh();
        }

        $engine = new RecommendationEngine();
        $result = $engine->generate($user, $included, $excluded, $overrides, $focusMuscles);

        // Replace any abandoned draft, while preserving the accepted plan
        // until the user explicitly approves this new one.
        Workout::where('user_id', $user->id)
            ->where('is_generated', true)
            ->where('is_accepted', false)
            ->delete();

        $planId = (string) Str::uuid();
        $workouts = [];
        foreach ($result['workouts'] as $workoutData) {
            $workouts[] = Workout::create([
                'user_id' => $user->id,
                'plan_id' => $planId,
                'name' => $workoutData['name'],
                'day_of_week' => (string) $workoutData['day_of_week'],
                'estimated_duration_minutes' => $workoutData['estimated_duration_minutes'],
                'exercises' => $workoutData['exercises'],
                'is_generated' => true,
                'is_accepted' => false,
            ]);
        }

        return response()->json([
            'success' => true,
            'data' => $workouts,
            'meta' => $result['meta'] ?? [],
        ], 201);
    }

    /**
     * List only generated workouts for the authenticated user.
     */
    public function generated(Request $request): JsonResponse
    {
        $workouts = Workout::where('user_id', $request->user()->id)
            ->where('is_generated', true)
            ->where('is_accepted', true)
            ->orderBy('day_of_week')
            ->get();

        return response()->json(['success' => true, 'data' => $workouts]);
    }

    /** Accept a generated draft and atomically replace the active plan. */
    public function acceptPlan(Request $request, string $planId): JsonResponse
    {
        $userId = $request->user()->id;
        $drafts = Workout::where('user_id', $userId)
            ->where('plan_id', $planId)
            ->where('is_generated', true)
            ->where('is_accepted', false)
            ->get();

        if ($drafts->isEmpty()) {
            abort(404);
        }

        DB::transaction(function () use ($userId, $planId): void {
            Workout::where('user_id', $userId)
                ->where('is_generated', true)
                ->where('is_accepted', true)
                ->delete();

            Workout::where('user_id', $userId)
                ->where('plan_id', $planId)
                ->where('is_accepted', false)
                ->update([
                    'is_accepted' => true,
                    'accepted_at' => now(),
                ]);
        });

        $accepted = Workout::where('user_id', $userId)
            ->where('plan_id', $planId)
            ->where('is_accepted', true)
            ->orderBy('day_of_week')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $accepted,
            'message' => 'Workout plan accepted.',
        ]);
    }

    /** Customize a generated workout using an ordered list of exercise IDs. */
    public function customize(Request $request, Workout $workout, WorkoutPrescriptionPolicy $policy): JsonResponse
    {
        if ((int) $workout->user_id !== (int) $request->user()->id || !$workout->is_generated) {
            abort(404);
        }

        $validated = $request->validate([
            'exercise_ids' => ['required', 'array', 'min:1', 'max:10'],
            'exercise_ids.*' => ['required', 'integer', 'distinct', 'exists:exercises,id'],
            'sets' => ['prohibited'],
            'reps' => ['prohibited'],
            'duration_seconds' => ['prohibited'],
            'rest_seconds' => ['prohibited'],
            'exercises' => ['prohibited'],
        ]);

        $profile = $request->user()->profile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Complete your profile before customizing workouts.'], 422);
        }

        $ids = array_map('intval', $validated['exercise_ids']);
        $models = \App\Models\Exercise::whereIn('id', $ids)->get()->keyBy('id');

        // Infer the workout's training environment from the equipment of
        // its existing exercises rather than the profile's current preference.
        // The profile preference may have changed since the workout was
        // generated (e.g. user was at the gym but later switched profile to
        // outdoor). If any existing workout exercise uses gym equipment
        // (anything other than bodyweight or pull_up_bar), the workout is
        // treated as a gym workout regardless of the profile value.
        $existingExerciseIds = collect($workout->exercises)->pluck('exercise_id')->filter()->toArray();
        $existingModels = \App\Models\Exercise::whereIn('id', $existingExerciseIds)->get();
        $workoutEnvironment = $profile->workout_preference;
        foreach ($existingModels as $existingExercise) {
            $equipment = strtolower(trim($existingExercise->equipment ?? ''));
            if ($equipment !== '' && $equipment !== 'bodyweight' && $equipment !== 'pull_up_bar') {
                $workoutEnvironment = 'gym';
                break;
            }
        }

        $ineligible = $models->first(
            fn (\App\Models\Exercise $exercise) => !in_array(
                $workoutEnvironment,
                $exercise->environments ?? [],
                true
            )
        );
        if ($ineligible !== null) {
            return response()->json([
                'success' => false,
                'message' => 'An exercise is unavailable in your selected workout environment.',
                'errors' => [
                    'exercise_ids' => ["{$ineligible->name} is not classified for {$workoutEnvironment} workouts."],
                ],
            ], 422);
        }

        if ($profile->low_impact_only) {
            $highImpact = $models->first(
                fn (\App\Models\Exercise $exercise) => $exercise->impact_level !== 'low'
            );
            if ($highImpact !== null) {
                return response()->json([
                    'success' => false,
                    'message' => 'An exercise is not low-impact.',
                    'errors' => [
                        'exercise_ids' => ["{$highImpact->name} is not low-impact and your profile is set to low-impact only."],
                    ],
                ], 422);
            }
        }

        $patternCounts = [];
        $muscleSets = [];
        $prescriptions = [];

        // Compute BMI modifiers once so the customization prescription
        // respects the same set-cap and rest-buffer rules as generation.
        $bmiForCustomize = ($profile->weight_kg > 0 && $profile->height_cm > 0)
            ? (float) $profile->weight_kg / pow((float) $profile->height_cm / 100, 2)
            : null;
        $bmiModsForCustomize = (new \App\Services\RecommendationEngine())->publicBmiModifiers($bmiForCustomize, $profile->goal);

        foreach ($ids as $index => $id) {
            $exercise = $models[$id];
            $patternKey = ($exercise->muscle_group ?? 'unknown').'|'.($exercise->movement_pattern ?? 'unknown');
            $patternCounts[$patternKey] = ($patternCounts[$patternKey] ?? 0) + 1;
            if ($patternCounts[$patternKey] > 2) {
                return response()->json(['success' => false, 'message' => 'Too many exercises repeat the same muscle and movement pattern.', 'errors' => ['exercise_ids' => ['Choose a different movement pattern to avoid redundant fatigue.']]], 422);
            }

            $prescription = $policy->prescribe($exercise, $profile->fitness_level, $profile->goal, $index + 1, $bmiModsForCustomize);
            foreach (($exercise->primary_muscles ?? [$exercise->muscle_group]) as $muscle) {
                $muscleSets[$muscle] = ($muscleSets[$muscle] ?? 0) + $prescription['sets'];
                if ($muscleSets[$muscle] > 10) {
                    return response()->json(['success' => false, 'message' => 'This workout exceeds the per-muscle set limit.', 'errors' => ['exercise_ids' => ["Reduce exercises targeting {$muscle}."]]], 422);
                }
            }
            $prescriptions[] = $prescription;
        }

        $workout->update([
            'exercises' => $prescriptions,
            'estimated_duration_minutes' => $policy->estimatedDurationMinutes($prescriptions),
        ]);

        return response()->json(['success' => true, 'data' => $workout->fresh()]);
    }
    /**
     * Returns the fitness goals that are clinically appropriate for a given BMI.
     *
     * Underweight (< 18.5)       : Build Muscle, Improve Endurance only.
     * Healthy (18.5-24.9)        : all four goals are available.
     * Overweight / Obesity (>= 25): Lose Weight, Build Muscle, Improve Endurance.
     *
     * @return string[]
     */
    private function allowedGoalsForBmi(float $bmi): array
    {
        if ($bmi < 18.5) {
            return ['build_muscle', 'increase_stamina'];
        }
        if ($bmi <= 24.9) {
            return ['lose_weight', 'build_muscle', 'stay_fit', 'increase_stamina'];
        }
        return ['lose_weight', 'build_muscle', 'increase_stamina'];
    }
}