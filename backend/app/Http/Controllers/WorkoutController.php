<?php

namespace App\Http\Controllers;

use App\Models\Workout;
use App\Services\RecommendationEngine;
use App\Services\WorkoutPrescriptionPolicy;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WorkoutController extends Controller
{
    /**
     * List authenticated user's workouts, optionally filter by is_generated.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Workout::where('user_id', $request->user()->id);

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
        ]);

        $included = $validated['included_exercises'] ?? [];
        $excluded = $validated['excluded_exercises'] ?? [];

        $engine = new RecommendationEngine();
        $result = $engine->generate($user, $included, $excluded);

        // Delete previous generated workouts for this user
        Workout::where('user_id', $user->id)
            ->where('is_generated', true)
            ->delete();

        // Store the generated workouts
        $workouts = [];
        foreach ($result['workouts'] as $workoutData) {
            $workouts[] = Workout::create([
                'user_id' => $user->id,
                'name' => $workoutData['name'],
                'day_of_week' => (string) $workoutData['day_of_week'],
                'estimated_duration_minutes' => $workoutData['estimated_duration_minutes'],
                'exercises' => $workoutData['exercises'],
                'is_generated' => true,
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
            ->orderBy('day_of_week')
            ->get();

        return response()->json(['success' => true, 'data' => $workouts]);
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
        $patternCounts = [];
        $muscleSets = [];
        $prescriptions = [];

        foreach ($ids as $index => $id) {
            $exercise = $models[$id];
            $patternKey = ($exercise->muscle_group ?? 'unknown').'|'.($exercise->movement_pattern ?? 'unknown');
            $patternCounts[$patternKey] = ($patternCounts[$patternKey] ?? 0) + 1;
            if ($patternCounts[$patternKey] > 2) {
                return response()->json(['success' => false, 'message' => 'Too many exercises repeat the same muscle and movement pattern.', 'errors' => ['exercise_ids' => ['Choose a different movement pattern to avoid redundant fatigue.']]], 422);
            }

            $prescription = $policy->prescribe($exercise, $profile->fitness_level, $profile->goal, $index + 1);
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
}
