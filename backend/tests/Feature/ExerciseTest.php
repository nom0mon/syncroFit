<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ExerciseTest extends TestCase
{
    use RefreshDatabase;

    public function test_can_list_exercises_with_pagination(): void
    {
        Sanctum::actingAs(User::factory()->create());

        Exercise::factory()->count(25)->create();

        $response = $this->getJson('/api/exercises?page=1');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonCount(20, 'data.exercises')
            ->assertJsonPath('data.pagination.current_page', 1)
            ->assertJsonPath('data.pagination.total_count', 25)
            ->assertJsonPath('data.pagination.total_pages', 2);
    }

    public function test_exercises_are_sorted_alphabetically_by_name(): void
    {
        Sanctum::actingAs(User::factory()->create());

        Exercise::factory()->create(['name' => 'Zottman Curl']);
        Exercise::factory()->create(['name' => 'Bench Press']);
        Exercise::factory()->create(['name' => 'Arnold Press']);
        Exercise::factory()->create(['name' => 'Deadlift']);

        $response = $this->getJson('/api/exercises');

        $response->assertStatus(200);

        $names = collect($response->json('data.exercises'))->pluck('name')->all();
        $this->assertEquals(['Arnold Press', 'Bench Press', 'Deadlift', 'Zottman Curl'], $names);
    }

    public function test_can_filter_exercises_by_muscle_group(): void
    {
        Sanctum::actingAs(User::factory()->create());

        Exercise::factory()->count(3)->create(['muscle_group' => 'chest']);
        Exercise::factory()->count(2)->create(['muscle_group' => 'back']);
        Exercise::factory()->count(1)->create(['muscle_group' => 'legs']);

        $response = $this->getJson('/api/exercises?muscle_group=chest');

        $response->assertStatus(200)
            ->assertJsonCount(3, 'data.exercises');

        $exercises = $response->json('data.exercises');
        foreach ($exercises as $exercise) {
            $this->assertEquals('chest', $exercise['muscle_group']);
        }
    }

    public function test_can_filter_exercises_by_difficulty(): void
    {
        Sanctum::actingAs(User::factory()->create());

        Exercise::factory()->count(4)->create(['difficulty' => 'beginner']);
        Exercise::factory()->count(2)->create(['difficulty' => 'intermediate']);
        Exercise::factory()->count(1)->create(['difficulty' => 'advanced']);

        $response = $this->getJson('/api/exercises?difficulty=beginner');

        $response->assertStatus(200)
            ->assertJsonCount(4, 'data.exercises');

        $exercises = $response->json('data.exercises');
        foreach ($exercises as $exercise) {
            $this->assertEquals('beginner', $exercise['difficulty']);
        }
    }

    public function test_can_filter_exercises_by_equipment(): void
    {
        Sanctum::actingAs(User::factory()->create());

        Exercise::factory()->count(3)->create(['equipment' => 'dumbbell']);
        Exercise::factory()->count(2)->create(['equipment' => 'barbell']);
        Exercise::factory()->count(1)->create(['equipment' => 'bodyweight']);

        $response = $this->getJson('/api/exercises?equipment=dumbbell');

        $response->assertStatus(200)
            ->assertJsonCount(3, 'data.exercises');

        $exercises = $response->json('data.exercises');
        foreach ($exercises as $exercise) {
            $this->assertEquals('dumbbell', $exercise['equipment']);
        }
    }

    public function test_can_combine_multiple_filters(): void
    {
        Sanctum::actingAs(User::factory()->create());

        // Matches both filters
        Exercise::factory()->count(2)->create([
            'muscle_group' => 'chest',
            'difficulty' => 'beginner',
        ]);
        // Matches only muscle_group
        Exercise::factory()->count(3)->create([
            'muscle_group' => 'chest',
            'difficulty' => 'advanced',
        ]);
        // Matches only difficulty
        Exercise::factory()->count(2)->create([
            'muscle_group' => 'back',
            'difficulty' => 'beginner',
        ]);

        $response = $this->getJson('/api/exercises?muscle_group=chest&difficulty=beginner');

        $response->assertStatus(200)
            ->assertJsonCount(2, 'data.exercises');

        $exercises = $response->json('data.exercises');
        foreach ($exercises as $exercise) {
            $this->assertEquals('chest', $exercise['muscle_group']);
            $this->assertEquals('beginner', $exercise['difficulty']);
        }
    }

    public function test_invalid_enum_filter_values_are_ignored(): void
    {
        Sanctum::actingAs(User::factory()->create());

        Exercise::factory()->count(5)->create();

        $response = $this->getJson('/api/exercises?muscle_group=invalid_group');

        $response->assertStatus(200)
            ->assertJsonCount(5, 'data.exercises')
            ->assertJsonPath('data.pagination.total_count', 5);
    }

    public function test_custom_page_size(): void
    {
        Sanctum::actingAs(User::factory()->create());

        Exercise::factory()->count(10)->create();

        $response = $this->getJson('/api/exercises?page_size=5');

        $response->assertStatus(200)
            ->assertJsonCount(5, 'data.exercises')
            ->assertJsonPath('data.pagination.total_count', 10)
            ->assertJsonPath('data.pagination.total_pages', 2);
    }

    public function test_page_less_than_1_treated_as_page_1(): void
    {
        Sanctum::actingAs(User::factory()->create());

        Exercise::factory()->count(5)->create();

        // page=0 should be treated as page 1
        $response = $this->getJson('/api/exercises?page=0');
        $response->assertStatus(200)
            ->assertJsonPath('data.pagination.current_page', 1)
            ->assertJsonCount(5, 'data.exercises');

        // page=-1 should also be treated as page 1
        $response = $this->getJson('/api/exercises?page=-1');
        $response->assertStatus(200)
            ->assertJsonPath('data.pagination.current_page', 1)
            ->assertJsonCount(5, 'data.exercises');
    }

    public function test_can_get_single_exercise(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $exercise = Exercise::factory()->create([
            'name' => 'Bench Press',
            'muscle_group' => 'chest',
            'difficulty' => 'intermediate',
            'equipment' => 'barbell',
            'default_sets' => 3,
            'default_reps' => 10,
        ]);

        $response = $this->getJson("/api/exercises/{$exercise->id}");

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.id', $exercise->id)
            ->assertJsonPath('data.name', 'Bench Press')
            ->assertJsonPath('data.muscle_group', 'chest')
            ->assertJsonPath('data.difficulty', 'intermediate')
            ->assertJsonPath('data.equipment', 'barbell')
            ->assertJsonPath('data.default_sets', 3)
            ->assertJsonPath('data.default_reps', 10);
    }

    public function test_get_nonexistent_exercise_returns_404(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/exercises/99999');

        $response->assertStatus(404)
            ->assertJsonPath('success', false);
    }

    public function test_unauthenticated_request_returns_401(): void
    {
        $response = $this->getJson('/api/exercises');

        $response->assertStatus(401);
    }
}
