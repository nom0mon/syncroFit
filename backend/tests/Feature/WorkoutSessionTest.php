<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\ProgressRecord;
use App\Models\Recommendation;
use App\Models\User;
use App\Models\Workout;
use App\Models\WorkoutExercise;
use App\Models\WorkoutSession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WorkoutSessionTest extends TestCase
{
    use RefreshDatabase;

    private User $user;
    private Workout $workout;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();

        // Create a recommendation, workout, and exercises
        $recommendation = Recommendation::create([
            'user_id' => $this->user->id,
            'week_start' => now()->startOfWeek()->toDateString(),
            'plan_data' => [],
        ]);

        $this->workout = Workout::create([
            'recommendation_id' => $recommendation->id,
            'name' => 'Test Workout',
            'day_of_week' => 1,
            'estimated_duration_minutes' => 45,
        ]);

        // Create exercises and link them to the workout
        $exercises = Exercise::factory()->count(3)->create();
        foreach ($exercises as $index => $exercise) {
            WorkoutExercise::create([
                'workout_id' => $this->workout->id,
                'exercise_id' => $exercise->id,
                'sets' => 3,
                'reps' => 10,
                'rest_seconds' => 60,
                'order' => $index + 1,
            ]);
        }
    }

    // --- STORE (POST /api/sessions) ---

    public function test_user_can_start_workout_session(): void
    {
        Sanctum::actingAs($this->user);

        $response = $this->postJson('/api/sessions', [
            'workout_id' => $this->workout->id,
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'started')
            ->assertJsonPath('data.user_id', $this->user->id)
            ->assertJsonPath('data.workout_id', $this->workout->id);

        // Should have 3 session exercises
        $this->assertCount(3, $response->json('data.session_exercises'));
        $this->assertEquals('pending', $response->json('data.session_exercises.0.status'));
    }

    public function test_start_session_rejects_if_active_session_exists(): void
    {
        Sanctum::actingAs($this->user);

        // Start first session
        $this->postJson('/api/sessions', ['workout_id' => $this->workout->id]);

        // Try to start another
        $response = $this->postJson('/api/sessions', ['workout_id' => $this->workout->id]);

        $response->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'An active workout session already exists');
    }

    public function test_start_session_rejects_if_paused_session_exists(): void
    {
        Sanctum::actingAs($this->user);

        // Create a paused session
        WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'paused',
            'started_at' => now(),
            'pause_log' => [['paused_at' => now()->toIso8601String()]],
        ]);

        $response = $this->postJson('/api/sessions', ['workout_id' => $this->workout->id]);

        $response->assertStatus(409)
            ->assertJsonPath('success', false);
    }

    public function test_start_session_allows_after_completed_session(): void
    {
        Sanctum::actingAs($this->user);

        // Create a completed session
        WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'completed',
            'started_at' => now()->subHour(),
            'completed_at' => now(),
            'total_duration_seconds' => 3600,
            'pause_log' => [],
        ]);

        $response = $this->postJson('/api/sessions', ['workout_id' => $this->workout->id]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'started');
    }

    public function test_start_session_requires_workout_id(): void
    {
        Sanctum::actingAs($this->user);

        $response = $this->postJson('/api/sessions', []);

        $response->assertStatus(422);
    }

    // --- PAUSE (PATCH /api/sessions/{id}/pause) ---

    public function test_user_can_pause_started_session(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'started',
            'started_at' => now(),
            'pause_log' => [],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/pause");

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'paused');

        // pause_log should have one entry with paused_at
        $pauseLog = $response->json('data.pause_log');
        $this->assertCount(1, $pauseLog);
        $this->assertArrayHasKey('paused_at', $pauseLog[0]);
    }

    public function test_pause_rejects_if_not_started(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'paused',
            'started_at' => now(),
            'pause_log' => [['paused_at' => now()->toIso8601String()]],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/pause");

        $response->assertStatus(422)
            ->assertJsonPath('success', false);

        $this->assertStringContainsString('Cannot pause session', $response->json('message'));
        $this->assertStringContainsString('paused', $response->json('message'));
    }

    public function test_pause_rejects_if_completed(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'completed',
            'started_at' => now()->subHour(),
            'completed_at' => now(),
            'total_duration_seconds' => 3600,
            'pause_log' => [],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/pause");

        $response->assertStatus(422)
            ->assertJsonPath('success', false);

        $this->assertStringContainsString('Cannot pause session', $response->json('message'));
    }

    // --- RESUME (PATCH /api/sessions/{id}/resume) ---

    public function test_user_can_resume_paused_session(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'paused',
            'started_at' => now()->subMinutes(10),
            'pause_log' => [['paused_at' => now()->subMinutes(5)->toIso8601String()]],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/resume");

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'started');

        // pause_log should have resumed_at set
        $pauseLog = $response->json('data.pause_log');
        $this->assertCount(1, $pauseLog);
        $this->assertArrayHasKey('resumed_at', $pauseLog[0]);
    }

    public function test_resume_rejects_if_not_paused(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'started',
            'started_at' => now(),
            'pause_log' => [],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/resume");

        $response->assertStatus(422)
            ->assertJsonPath('success', false);

        $this->assertStringContainsString('Cannot resume session', $response->json('message'));
        $this->assertStringContainsString('started', $response->json('message'));
    }

    // --- SKIP EXERCISE (PATCH /api/sessions/{id}/skip-exercise) ---

    public function test_user_can_skip_exercise(): void
    {
        Sanctum::actingAs($this->user);

        // Create session via API
        $storeResponse = $this->postJson('/api/sessions', [
            'workout_id' => $this->workout->id,
        ]);

        $sessionId = $storeResponse->json('data.id');
        $exerciseId = $storeResponse->json('data.session_exercises.0.exercise_id');

        $response = $this->patchJson("/api/sessions/{$sessionId}/skip-exercise", [
            'exercise_id' => $exerciseId,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        // Verify the exercise was marked as skipped
        $sessionExercises = $response->json('data.session_exercises');
        $skipped = collect($sessionExercises)->firstWhere('exercise_id', $exerciseId);
        $this->assertEquals('skipped', $skipped['status']);
    }

    public function test_skip_exercise_returns_404_for_unknown_exercise(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'started',
            'started_at' => now(),
            'pause_log' => [],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/skip-exercise", [
            'exercise_id' => 99999,
        ]);

        $response->assertStatus(404)
            ->assertJsonPath('success', false);
    }

    public function test_skip_exercise_rejects_on_completed_session(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'completed',
            'started_at' => now()->subHour(),
            'completed_at' => now(),
            'total_duration_seconds' => 3600,
            'pause_log' => [],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/skip-exercise", [
            'exercise_id' => 1,
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Cannot modify completed session');
    }

    // --- COMPLETE (PATCH /api/sessions/{id}/complete) ---

    public function test_user_can_complete_started_session(): void
    {
        Sanctum::actingAs($this->user);

        // Create session via API for proper session_exercises
        $storeResponse = $this->postJson('/api/sessions', [
            'workout_id' => $this->workout->id,
        ]);

        $sessionId = $storeResponse->json('data.id');

        // Wait a moment to ensure time difference
        $response = $this->patchJson("/api/sessions/{$sessionId}/complete");

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'completed');

        $this->assertNotNull($response->json('data.completed_at'));
        $this->assertIsInt($response->json('data.total_duration_seconds'));
        $this->assertGreaterThanOrEqual(0, $response->json('data.total_duration_seconds'));

        // All pending exercises should be marked completed
        $exercises = $response->json('data.session_exercises');
        foreach ($exercises as $ex) {
            $this->assertEquals('completed', $ex['status']);
        }
    }

    public function test_complete_closes_last_pause_entry_if_paused(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'paused',
            'started_at' => now()->subMinutes(30),
            'pause_log' => [['paused_at' => now()->subMinutes(10)->toIso8601String()]],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/complete");

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'completed');

        // pause_log should have resumed_at set on the last entry
        $pauseLog = $response->json('data.pause_log');
        $this->assertArrayHasKey('resumed_at', $pauseLog[0]);
    }

    public function test_complete_rejects_already_completed_session(): void
    {
        Sanctum::actingAs($this->user);

        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'completed',
            'started_at' => now()->subHour(),
            'completed_at' => now(),
            'total_duration_seconds' => 3600,
            'pause_log' => [],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/complete");

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Session is already completed');
    }

    public function test_complete_excludes_paused_time_from_duration(): void
    {
        Sanctum::actingAs($this->user);

        $startedAt = now()->subMinutes(60);
        $pausedAt = now()->subMinutes(40);
        $resumedAt = now()->subMinutes(20);

        // 60 min total, 20 min paused → 40 min active
        $session = WorkoutSession::create([
            'user_id' => $this->user->id,
            'workout_id' => $this->workout->id,
            'status' => 'started',
            'started_at' => $startedAt,
            'pause_log' => [
                [
                    'paused_at' => $pausedAt->toIso8601String(),
                    'resumed_at' => $resumedAt->toIso8601String(),
                ],
            ],
        ]);

        $response = $this->patchJson("/api/sessions/{$session->id}/complete");

        $response->assertStatus(200);

        $totalDuration = $response->json('data.total_duration_seconds');
        // Elapsed ~3600s, paused ~1200s, so duration should be ~2400s
        // Allow tolerance because of test execution time
        $this->assertGreaterThan(2300, $totalDuration);
        $this->assertLessThan(2500, $totalDuration);
    }

    // --- AUTHORIZATION ---

    public function test_session_not_found_returns_404(): void
    {
        Sanctum::actingAs($this->user);

        $response = $this->patchJson('/api/sessions/99999/pause');

        $response->assertStatus(404)
            ->assertJsonPath('success', false);
    }

    public function test_cannot_access_other_users_session(): void
    {
        $otherUser = User::factory()->create();

        $session = WorkoutSession::create([
            'user_id' => $otherUser->id,
            'workout_id' => $this->workout->id,
            'status' => 'started',
            'started_at' => now(),
            'pause_log' => [],
        ]);

        Sanctum::actingAs($this->user);

        $response = $this->patchJson("/api/sessions/{$session->id}/pause");

        $response->assertStatus(404)
            ->assertJsonPath('success', false);
    }

    public function test_unauthenticated_requests_return_401(): void
    {
        $response = $this->postJson('/api/sessions', ['workout_id' => $this->workout->id]);
        $response->assertStatus(401);

        $response = $this->patchJson('/api/sessions/1/pause');
        $response->assertStatus(401);

        $response = $this->patchJson('/api/sessions/1/resume');
        $response->assertStatus(401);

        $response = $this->patchJson('/api/sessions/1/skip-exercise', ['exercise_id' => 1]);
        $response->assertStatus(401);

        $response = $this->patchJson('/api/sessions/1/complete');
        $response->assertStatus(401);
    }

    // --- PROGRESS RECORD ON COMPLETION ---

    public function test_completing_session_creates_progress_record(): void
    {
        Sanctum::actingAs($this->user);

        // Create session via API
        $storeResponse = $this->postJson('/api/sessions', [
            'workout_id' => $this->workout->id,
        ]);

        $sessionId = $storeResponse->json('data.id');

        // Complete the session
        $response = $this->patchJson("/api/sessions/{$sessionId}/complete");
        $response->assertStatus(200);

        // Verify ProgressRecord exists for today with workouts_completed = 1
        $today = now()->toDateString();
        $progressRecord = ProgressRecord::where('user_id', $this->user->id)
            ->where('recorded_at', $today)
            ->first();

        $this->assertNotNull($progressRecord);
        $this->assertEquals(1, $progressRecord->workouts_completed);
        $this->assertNull($progressRecord->weight_kg);
        $this->assertNull($progressRecord->bmi);
    }

    public function test_completing_second_session_increments_progress_record(): void
    {
        Sanctum::actingAs($this->user);

        $today = now()->toDateString();

        // Create an existing ProgressRecord with workouts_completed = 1
        ProgressRecord::create([
            'user_id' => $this->user->id,
            'recorded_at' => $today,
            'weight_kg' => 75.50,
            'bmi' => 24.22,
            'workouts_completed' => 1,
        ]);

        // Create session via API
        $storeResponse = $this->postJson('/api/sessions', [
            'workout_id' => $this->workout->id,
        ]);

        $sessionId = $storeResponse->json('data.id');

        // Complete the session
        $response = $this->patchJson("/api/sessions/{$sessionId}/complete");
        $response->assertStatus(200);

        // Verify ProgressRecord has workouts_completed = 2 and preserved weight/bmi
        $progressRecord = ProgressRecord::where('user_id', $this->user->id)
            ->where('recorded_at', $today)
            ->first();

        $this->assertNotNull($progressRecord);
        $this->assertEquals(2, $progressRecord->workouts_completed);
        $this->assertEquals('75.50', $progressRecord->weight_kg);
        $this->assertEquals('24.22', $progressRecord->bmi);
    }
}
