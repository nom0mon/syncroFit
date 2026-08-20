<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WorkoutGenerationContractTest extends TestCase
{
    use RefreshDatabase;

    public function test_generated_workouts_use_the_mobile_exercise_json_contract(): void
    {
        $user = User::factory()->create();
        $user->profile()->create([
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => 'stay_fit',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ]);
        Exercise::factory()->create([
            'muscle_group' => 'chest',
            'equipment' => 'dumbbell',
            'difficulty' => 'intermediate',
            'default_duration_seconds' => 45,
        ]);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate');

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonCount(1, 'data');

        $exercises = $response->json('data.0.exercises');
        $this->assertNotEmpty($exercises);
        foreach ($exercises as $exercise) {
            $this->assertArrayHasKey('duration_seconds', $exercise);
            $this->assertIsInt($exercise['duration_seconds']);
            $this->assertArrayNotHasKey('rest_seconds', $exercise);
        }
    }
}
