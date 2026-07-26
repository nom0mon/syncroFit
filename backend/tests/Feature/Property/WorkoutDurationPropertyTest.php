<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use App\Models\Recommendation;
use App\Models\User;
use App\Models\Workout;
use App\Models\WorkoutExercise;
use App\Models\WorkoutSession;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Property Test: Workout Duration Excludes Paused Time (Property 16)
 *
 * For any completed workout session with a sequence of start, pause, resume, and complete events,
 * the total_duration_seconds SHALL equal the total elapsed time from start to complete
 * MINUS the sum of all paused intervals (time between each pause and its corresponding resume).
 *
 * **Validates: Requirements 9.7**
 */
class WorkoutDurationPropertyTest extends TestCase
{
    use RefreshDatabase;

    private User $user;
    private Workout $workout;

    protected function setUp(): void
    {
        parent::setUp();

        // Create a user, recommendation, workout, and exercises for the session
        $this->user = User::factory()->create();

        $recommendation = Recommendation::create([
            'user_id' => $this->user->id,
            'week_start' => now()->startOfWeek()->toDateString(),
            'plan_data' => [],
        ]);

        $this->workout = Workout::create([
            'recommendation_id' => $recommendation->id,
            'name' => 'Test Workout',
            'day_of_week' => 1,
            'estimated_duration_minutes' => 30,
        ]);

        $exercise = Exercise::factory()->create();

        WorkoutExercise::create([
            'workout_id' => $this->workout->id,
            'exercise_id' => $exercise->id,
            'sets' => 3,
            'reps' => 10,
            'rest_seconds' => 60,
            'order' => 1,
        ]);
    }

    /**
     * Property 16: Workout Duration Excludes Paused Time
     *
     * Generate random sequences of start/pause/resume/complete timestamps,
     * verify total_duration_seconds equals elapsed time minus sum of paused intervals.
     *
     * **Validates: Requirements 9.7**
     */
    public function test_duration_excludes_paused_time_property(): void
    {
        Sanctum::actingAs($this->user);

        for ($i = 0; $i < 50; $i++) {
            // Generate random scenario
            $startedMinutesAgo = mt_rand(10, 120); // session started 10-120 minutes ago
            $startedAt = Carbon::now()->subMinutes($startedMinutesAgo);

            // Generate 0-5 random pause intervals
            $numPauses = mt_rand(0, 5);
            $pauseLog = [];
            $totalPausedSeconds = 0;
            $currentTime = $startedAt->copy();

            for ($p = 0; $p < $numPauses; $p++) {
                $activeSeconds = mt_rand(30, 300); // 30s - 5min active before pause
                $pausedAt = $currentTime->copy()->addSeconds($activeSeconds);
                $pausedSeconds = mt_rand(10, 300); // 10s - 5min paused
                $resumedAt = $pausedAt->copy()->addSeconds($pausedSeconds);

                $pauseLog[] = [
                    'paused_at' => $pausedAt->toIso8601String(),
                    'resumed_at' => $resumedAt->toIso8601String(),
                ];
                $totalPausedSeconds += $pausedSeconds;
                $currentTime = $resumedAt;
            }

            // Create session directly in DB with known started_at and pause_log
            $session = WorkoutSession::create([
                'user_id' => $this->user->id,
                'workout_id' => $this->workout->id,
                'status' => 'started',
                'started_at' => $startedAt,
                'pause_log' => $pauseLog,
            ]);

            // Freeze time to a known point after the last resume
            $completionTime = $currentTime->copy()->addSeconds(mt_rand(30, 300));
            Carbon::setTestNow($completionTime);

            // Complete via API
            $response = $this->patchJson("/api/sessions/{$session->id}/complete");

            $response->assertStatus(200);

            // Verify: total_duration = elapsed - totalPausedSeconds
            $elapsed = $completionTime->diffInSeconds($startedAt);
            $expectedDuration = $elapsed - $totalPausedSeconds;
            $actualDuration = $response->json('data.total_duration_seconds');

            $this->assertEqualsWithDelta(
                $expectedDuration,
                $actualDuration,
                2,
                "Iteration $i: Duration mismatch. "
                . "Elapsed: {$elapsed}s, Paused: {$totalPausedSeconds}s, "
                . "Expected: {$expectedDuration}s, Got: {$actualDuration}s, "
                . "Num pauses: $numPauses"
            );

            // Clean up for next iteration
            $session->delete();
            Carbon::setTestNow(); // Reset time
        }
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow(); // Ensure test time is always reset
        parent::tearDown();
    }
}
