<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RecommendationTest extends TestCase
{
    use RefreshDatabase;

    private function createUserWithProfile(array $overrides = []): User
    {
        $user = User::factory()->create();
        $user->profile()->create(array_merge([
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
            'bmi' => 22.86,
        ], $overrides));

        return $user;
    }

    private function seedExercises(int $count = 30): void
    {
        Exercise::factory()->count($count)->create();
    }

    public function test_generate_returns_422_when_no_profile(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/recommendations/generate');

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonStructure(['success', 'message', 'errors']);
    }

    public function test_generate_returns_422_when_profile_missing_goal(): void
    {
        $user = User::factory()->create();
        $user->profile()->create([
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => null,
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
            'bmi' => 22.86,
        ]);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/recommendations/generate');

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('errors.goal.0', 'The goal field is required.');
    }

    public function test_generate_returns_422_when_profile_missing_fitness_level(): void
    {
        $user = User::factory()->create();
        $user->profile()->create([
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => 'build_muscle',
            'fitness_level' => null,
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
            'bmi' => 22.86,
        ]);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/recommendations/generate');

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('errors.fitness_level.0', 'The fitness_level field is required.');
    }

    public function test_generate_creates_recommendation_with_workouts_and_exercises(): void
    {
        $user = $this->createUserWithProfile();
        Sanctum::actingAs($user);
        $this->seedExercises(30);

        $response = $this->postJson('/api/recommendations/generate');

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'id',
                    'user_id',
                    'week_start',
                    'plan_data',
                    'workouts' => [
                        '*' => [
                            'id',
                            'recommendation_id',
                            'name',
                            'day_of_week',
                            'estimated_duration_minutes',
                            'exercises' => [
                                '*' => [
                                    'id',
                                    'workout_id',
                                    'exercise_id',
                                    'sets',
                                    'reps',
                                    'rest_seconds',
                                    'order',
                                    'exercise',
                                ],
                            ],
                        ],
                    ],
                ],
                'message',
            ]);

        // Should have 3 workouts (one per availability day: monday, wednesday, friday)
        $this->assertCount(3, $response->json('data.workouts'));

        // Verify data was persisted
        $this->assertDatabaseHas('recommendations', [
            'user_id' => $user->id,
        ]);
    }

    public function test_generate_requires_authentication(): void
    {
        $response = $this->postJson('/api/recommendations/generate');

        $response->assertStatus(401);
    }

    public function test_current_returns_most_recent_recommendation(): void
    {
        $user = $this->createUserWithProfile();
        Sanctum::actingAs($user);
        $this->seedExercises(30);

        // Generate a recommendation first
        $this->postJson('/api/recommendations/generate');

        $response = $this->getJson('/api/recommendations/current');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'id',
                    'user_id',
                    'week_start',
                    'plan_data',
                    'workouts' => [
                        '*' => [
                            'id',
                            'name',
                            'day_of_week',
                            'exercises' => [
                                '*' => [
                                    'exercise',
                                ],
                            ],
                        ],
                    ],
                ],
                'message',
            ]);
    }

    public function test_current_returns_404_when_no_recommendation_exists(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/recommendations/current');

        $response->assertStatus(404)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'No recommendation found.');
    }

    public function test_current_requires_authentication(): void
    {
        $response = $this->getJson('/api/recommendations/current');

        $response->assertStatus(401);
    }
}
