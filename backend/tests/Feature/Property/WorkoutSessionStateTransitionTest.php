<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use App\Models\Recommendation;
use App\Models\SessionExercise;
use App\Models\User;
use App\Models\Workout;
use App\Models\WorkoutExercise;
use App\Models\WorkoutSession;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Property Test: Workout Session Invalid Transitions Rejected (Property 15)
 *
 * Generate random session states and random transition attempts,
 * verify invalid transitions are rejected with 422 and valid transitions succeed.
 *
 * **Validates: Requirements 9.5**
 */
class WorkoutSessionStateTransitionTest extends TestCase
{
    use RefreshDatabase;

    private array $validTransitions = [
        'started' => ['pause', 'complete', 'skip-exercise'],
        'paused' => ['resume', 'complete', 'skip-exercise'],
        'completed' => [], // no valid transitions from completed
    ];

    private array $allTransitions = ['pause', 'resume', 'complete', 'skip-exercise'];

    /**
     * Property 15: Workout Session Invalid Transitions Rejected
     *
     * Generate random session states and random transition attempts,
     * verify invalid transitions are rejected with 422 status and success=false,
     * and valid transitions return a successful response.
     *
     * **Validates: Requirements 9.5**
     */
    public function test_invalid_state_transitions_rejected_property(): void
    {
        $states = ['started', 'paused', 'completed'];

        for ($i = 0; $i < 100; $i++) {
            $state = $states[mt_rand(0, count($states) - 1)];
            $transition = $this->allTransitions[mt_rand(0, count($this->allTransitions) - 1)];

            // Create a fresh user and session in the given state
            $user = User::factory()->create();
            Sanctum::actingAs($user);

            $session = $this->createSessionInState($user, $state);

            // Attempt the transition
            $response = $this->attemptTransition($session, $transition);

            $isValid = in_array($transition, $this->validTransitions[$state]);

            if (!$isValid) {
                $response->assertStatus(422);
                $response->assertJsonPath('success', false);
            } else {
                $response->assertSuccessful();
                $response->assertJsonPath('success', true);
            }
        }
    }

    /**
     * Create a workout session in the specified state.
     */
    private function createSessionInState(User $user, string $state): WorkoutSession
    {
        // Create supporting data: exercise, recommendation, workout, workout_exercise
        $exercise = Exercise::factory()->create();

        $recommendation = Recommendation::create([
            'user_id' => $user->id,
            'week_start' => Carbon::now()->startOfWeek()->toDateString(),
            'plan_data' => [],
        ]);

        $workout = Workout::create([
            'recommendation_id' => $recommendation->id,
            'name' => 'Test Workout ' . mt_rand(1, 10000),
            'day_of_week' => 1,
            'estimated_duration_minutes' => 30,
        ]);

        WorkoutExercise::create([
            'workout_id' => $workout->id,
            'exercise_id' => $exercise->id,
            'sets' => 3,
            'reps' => 10,
            'rest_seconds' => 60,
            'order' => 1,
        ]);

        $sessionData = [
            'user_id' => $user->id,
            'workout_id' => $workout->id,
            'status' => 'started',
            'started_at' => Carbon::now()->subMinutes(10),
            'pause_log' => [],
        ];

        if ($state === 'paused') {
            $sessionData['status'] = 'paused';
            $sessionData['pause_log'] = [
                ['paused_at' => Carbon::now()->subMinutes(5)->toIso8601String()],
            ];
        } elseif ($state === 'completed') {
            $sessionData['status'] = 'completed';
            $sessionData['completed_at'] = Carbon::now()->subMinutes(1);
            $sessionData['total_duration_seconds'] = 540;
        }

        $session = WorkoutSession::create($sessionData);

        // Create a SessionExercise record (needed for skip-exercise transitions)
        SessionExercise::create([
            'workout_session_id' => $session->id,
            'exercise_id' => $exercise->id,
            'status' => 'pending',
            'sets_completed' => 0,
            'reps_completed' => 0,
        ]);

        return $session;
    }

    /**
     * Attempt a state transition on the given session.
     */
    private function attemptTransition(WorkoutSession $session, string $transition): \Illuminate\Testing\TestResponse
    {
        $url = "/api/sessions/{$session->id}/{$transition}";

        $payload = [];
        if ($transition === 'skip-exercise') {
            // Get the exercise_id from session exercises
            $sessionExercise = SessionExercise::where('workout_session_id', $session->id)->first();
            $payload = ['exercise_id' => $sessionExercise->exercise_id];
        }

        return $this->patchJson($url, $payload);
    }
}
