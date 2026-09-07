<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use App\Models\Workout;
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
            $this->assertArrayHasKey('rest_seconds', $exercise);
            $this->assertIsInt($exercise['rest_seconds']);
        }
    }

    public function test_generated_plan_remains_draft_until_explicitly_accepted(): void
    {
        $user = User::factory()->create();
        $user->profile()->create([
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => 'stay_fit',
            'fitness_level' => 'beginner',
            'workout_preference' => 'home',
            'availability_days' => ['monday'],
        ]);
        Exercise::factory()->create([
            'muscle_group' => 'chest',
            'equipment' => 'bodyweight',
            'difficulty' => 'beginner',
            'default_duration_seconds' => 30,
        ]);
        $old = Workout::create([
            'user_id' => $user->id,
            'name' => 'Old accepted plan',
            'day_of_week' => '1',
            'estimated_duration_minutes' => 10,
            'exercises' => [],
            'is_generated' => true,
            'is_accepted' => true,
        ]);
        Sanctum::actingAs($user);

        $generated = $this->postJson('/api/workouts/generate')->assertCreated();
        $planId = $generated->json('data.0.plan_id');

        $this->assertNotNull($planId);
        $this->assertFalse($generated->json('data.0.is_accepted'));
        $this->getJson('/api/workouts')->assertJsonFragment(['name' => $old->name]);

        $this->postJson("/api/workouts/plans/{$planId}/accept")
            ->assertOk()
            ->assertJsonPath('message', 'Workout plan accepted.');

        $this->assertDatabaseMissing('workouts', ['id' => $old->id]);
        $this->assertDatabaseHas('workouts', [
            'plan_id' => $planId,
            'is_accepted' => true,
        ]);
    }
}
