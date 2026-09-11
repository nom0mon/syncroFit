<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use App\Models\Workout;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WorkoutCustomizationTest extends TestCase
{
    use RefreshDatabase;

    private function userWithProfile(string $level = 'intermediate'): User
    {
        $user = User::factory()->create();
        $user->profile()->create([
            'age' => 25, 'height_cm' => 175, 'weight_kg' => 70,
            'gender' => 'male', 'goal' => 'build_muscle',
            'fitness_level' => $level, 'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ]);
        return $user;
    }

    public function test_owner_can_customize_and_server_assigns_prescription(): void
    {
        $user = $this->userWithProfile();
        $first = Exercise::factory()->create(['default_duration_seconds' => 0, 'exercise_type' => 'compound']);
        $second = Exercise::factory()->create(['default_duration_seconds' => 0, 'exercise_type' => 'isolation']);
        $workout = Workout::create(['user_id' => $user->id, 'name' => 'Upper A', 'exercises' => [], 'is_generated' => true]);
        Sanctum::actingAs($user);

        $this->putJson("/api/workouts/{$workout->id}/exercises", [
            'exercise_ids' => [$second->id, $first->id],
        ])->assertOk()
            ->assertJsonPath('data.exercises.0.exercise_id', $second->id)
            ->assertJsonPath('data.exercises.0.sets', 3)
            ->assertJsonPath('data.exercises.0.rest_seconds', 90)
            ->assertJsonPath('data.exercises.1.order', 2);

        $this->putJson("/api/workouts/{$workout->id}/exercises", [
            'exercise_ids' => [$first->id],
            'sets' => 99,
        ])->assertUnprocessable();
    }

    public function test_duplicate_empty_and_foreign_workouts_are_rejected(): void
    {
        $owner = $this->userWithProfile();
        $other = $this->userWithProfile();
        $exercise = Exercise::factory()->create();
        $workout = Workout::create(['user_id' => $owner->id, 'name' => 'Plan', 'exercises' => [], 'is_generated' => true]);
        Sanctum::actingAs($other);

        $this->putJson("/api/workouts/{$workout->id}/exercises", ['exercise_ids' => [$exercise->id]])->assertNotFound();
        Sanctum::actingAs($owner);
        $this->putJson("/api/workouts/{$workout->id}/exercises", ['exercise_ids' => []])->assertUnprocessable();
        $this->putJson("/api/workouts/{$workout->id}/exercises", ['exercise_ids' => [$exercise->id, $exercise->id]])->assertUnprocessable();
    }

    public function test_customization_rejects_exercises_outside_the_users_environment(): void
    {
        $user = $this->userWithProfile();
        $user->profile()->update(['workout_preference' => 'home']);
        $machineExercise = Exercise::factory()->create([
            'name' => 'Cable Fly',
            'equipment' => 'machine',
            'environments' => ['gym'],
        ]);
        $workout = Workout::create([
            'user_id' => $user->id,
            'name' => 'Home Plan',
            'exercises' => [],
            'is_generated' => true,
        ]);
        Sanctum::actingAs($user);

        $this->putJson("/api/workouts/{$workout->id}/exercises", [
            'exercise_ids' => [$machineExercise->id],
        ])->assertUnprocessable()
            ->assertJsonPath('errors.exercise_ids.0', 'Cable Fly is not classified for home workouts.');
    }
}
