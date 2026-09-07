<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WorkoutHistoryIdempotencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_replaying_the_same_client_mutation_does_not_duplicate_history(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $payload = [
            'client_mutation_id' => 'history-device-123',
            'workout_name' => 'Full Body A',
            'completed_at' => now()->toISOString(),
            'total_duration_seconds' => 900,
            'exercises_completed' => [[
                'exercise_id' => 1,
                'exercise_name' => 'Squat',
                'sets_completed' => 3,
                'reps_or_duration' => 10,
            ]],
        ];

        $first = $this->postJson('/api/workout-history', $payload);
        $second = $this->postJson('/api/workout-history', $payload);

        $first->assertCreated();
        $second->assertOk();
        $this->assertSame($first->json('data.id'), $second->json('data.id'));
        $this->assertDatabaseCount('workout_history', 1);
    }

    public function test_same_client_mutation_id_is_scoped_to_each_user(): void
    {
        $payload = [
            'client_mutation_id' => 'shared-device-id',
            'workout_name' => 'Workout',
            'completed_at' => now()->toISOString(),
            'total_duration_seconds' => 60,
            'exercises_completed' => [[
                'exercise_id' => 1,
                'exercise_name' => 'Plank',
                'sets_completed' => 1,
                'reps_or_duration' => 30,
                'is_duration' => true,
            ]],
        ];

        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/workout-history', $payload)->assertCreated();

        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/workout-history', $payload)->assertCreated();

        $this->assertDatabaseCount('workout_history', 2);
    }
}
