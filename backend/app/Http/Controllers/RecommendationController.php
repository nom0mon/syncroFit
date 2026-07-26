<?php

namespace App\Http\Controllers;

use App\Models\Recommendation;
use App\Models\Workout;
use App\Models\WorkoutExercise;
use App\Services\RecommendationEngine;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RecommendationController extends Controller
{
    /**
     * Generate a weekly workout plan for the authenticated user.
     *
     * POST /api/recommendations/generate
     */
    public function generate(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->profile;

        // Check profile completeness — return 422 if missing profile, goal, or fitness_level
        if (!$profile || !$profile->goal || !$profile->fitness_level) {
            $missingFields = [];
            if (!$profile) {
                $missingFields['profile'] = ['A complete profile is required before generating a recommendation.'];
            } else {
                if (!$profile->goal) {
                    $missingFields['goal'] = ['The goal field is required.'];
                }
                if (!$profile->fitness_level) {
                    $missingFields['fitness_level'] = ['The fitness_level field is required.'];
                }
            }

            return $this->errorResponse(
                'Profile is incomplete. Please complete your profile before generating a recommendation.',
                422,
                $missingFields
            );
        }

        // Invoke the recommendation engine
        $engine = new RecommendationEngine();
        $plan = $engine->generate($user);

        // Create the Recommendation record
        $recommendation = Recommendation::create([
            'user_id' => $user->id,
            'week_start' => Carbon::now()->startOfWeek(),
            'plan_data' => $plan,
        ]);

        // Create Workout and WorkoutExercise records
        foreach ($plan['workouts'] as $workoutData) {
            $workout = Workout::create([
                'recommendation_id' => $recommendation->id,
                'name' => $workoutData['name'],
                'day_of_week' => $workoutData['day_of_week'],
                'estimated_duration_minutes' => $workoutData['estimated_duration_minutes'],
            ]);

            foreach ($workoutData['exercises'] as $exerciseData) {
                WorkoutExercise::create([
                    'workout_id' => $workout->id,
                    'exercise_id' => $exerciseData['exercise_id'],
                    'sets' => $exerciseData['sets'],
                    'reps' => $exerciseData['reps'],
                    'rest_seconds' => $exerciseData['rest_seconds'],
                    'order' => $exerciseData['order'],
                ]);
            }
        }

        // Reload with eager-loaded relationships
        $recommendation->load('workouts.exercises.exercise');

        return $this->createdResponse($recommendation, 'Weekly workout plan generated successfully.');
    }

    /**
     * Get the current (most recent) recommendation for the authenticated user.
     *
     * GET /api/recommendations/current
     */
    public function current(Request $request): JsonResponse
    {
        $user = $request->user();

        $recommendation = Recommendation::where('user_id', $user->id)
            ->latest('created_at')
            ->with('workouts.exercises.exercise')
            ->first();

        if (!$recommendation) {
            return $this->errorResponse('No recommendation found.', 404);
        }

        return $this->successResponse($recommendation);
    }
}
