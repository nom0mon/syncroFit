<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WorkoutHistoryEmptyExercisesTest extends TestCase
{
    use RefreshDatabase;

    /**
     * A scheduled workout where the user skipped every exercise is a valid
     * completion. The client sends an empty exercises_completed array, which
     * the server must accept (present but empty), not reject with 422.
     */
    public function test_completion_with_zero_exercises_is_accepted(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workout-history', [
            'workout_name' => 'Full Body A',
            'completed_at' => now()->toISOString(),
            'total_duration_seconds' => 300,
            'exercises_completed' => [],
        ]);

        $response->assertCreated();
        $this->assertDatabaseCount('workout_history', 1);
        $this->assertSame([], $response->json('data.exercises_completed'));
    }

    /**
     * The field must still be present. A missing exercises_completed key is a
     * malformed payload and remains a 422.
     */
    public function test_missing_exercises_completed_key_is_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workout-history', [
            'workout_name' => 'Full Body A',
            'completed_at' => now()->toISOString(),
            'total_duration_seconds' => 300,
        ]);

        $response->assertStatus(422);
    }
}
