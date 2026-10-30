<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use App\Models\Workout;
use App\Services\RecommendationEngine;
use Database\Seeders\ExerciseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LowImpactTest extends TestCase
{
    use RefreshDatabase;

    private function userWithProfile(array $overrides = []): User
    {
        $user = User::factory()->create();
        $user->profile()->create(array_merge([
            'age' => 25, 'height_cm' => 175, 'weight_kg' => 70,
            'gender' => 'male', 'goal' => 'stay_fit',
            'fitness_level' => 'intermediate', 'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ], $overrides));

        return $user->load('profile');
    }

    private function gymKneeExercise(string $impact): Exercise
    {
        return Exercise::factory()->impact($impact)->create([
            'muscle_group' => 'legs',
            'movement_pattern' => 'knee_dominant',
            'equipment' => 'barbell',
            'environments' => ['gym'],
            'difficulty' => 'intermediate',
        ]);
    }

    public function test_profile_defaults_to_not_low_impact_and_catalog_is_tagged(): void
    {
        $user = $this->userWithProfile();
        $this->assertFalse($user->profile->low_impact_only);

        $this->seed(ExerciseSeeder::class);
        foreach (['Burpee', 'Jumping Jack', 'High Knees', 'Broad Jump'] as $name) {
            $this->assertSame('high', Exercise::where('name', $name)->value('impact_level'), $name);
        }
        $this->assertSame('moderate', Exercise::where('name', 'Dumbbell Clean and Press')->value('impact_level'));
        foreach (['Mountain Climber', 'Walking Lunge', 'Push-Up', 'Barbell Back Squat'] as $name) {
            $this->assertSame('low', Exercise::where('name', $name)->value('impact_level'), $name);
        }
        $this->assertSame(0, Exercise::whereNull('impact_level')->count());
    }

    public function test_engine_avoids_non_low_impact_exercises_only_when_enabled(): void
    {
        $high = $this->gymKneeExercise('high');
        $low = $this->gymKneeExercise('low');
        $engine = app(RecommendationEngine::class);

        // "included" adds +100 so the high-impact exercise wins unless filtered.
        $off = $this->userWithProfile(['low_impact_only' => false]);
        $ids = collect($engine->generate($off, [$high->id])['workouts'][0]['exercises'])->pluck('exercise_id');
        $this->assertContains($high->id, $ids->all());

        $on = $this->userWithProfile(['low_impact_only' => true]);
        $ids = collect($engine->generate($on, [$high->id])['workouts'][0]['exercises'])->pluck('exercise_id');
        $this->assertNotContains($high->id, $ids->all());
        $this->assertContains($low->id, $ids->all());
    }

    public function test_override_applies_to_one_generation_unless_saved_to_profile(): void
    {
        $this->gymKneeExercise('high');
        $this->gymKneeExercise('low');
        $user = $this->userWithProfile();
        Sanctum::actingAs($user);

        $this->postJson('/api/workouts/generate', ['low_impact_only' => true])->assertCreated();
        $this->assertFalse($user->profile->fresh()->low_impact_only);

        $this->postJson('/api/workouts/generate', [
            'low_impact_only' => true,
            'save_options_to_profile' => true,
        ])->assertCreated();
        $this->assertTrue($user->profile->fresh()->low_impact_only);

        $this->postJson('/api/workouts/generate', ['low_impact_only' => 'maybe'])->assertUnprocessable();
    }

    public function test_seeded_catalog_never_yields_non_low_impact_exercises_when_enabled(): void
    {
        $this->seed(ExerciseSeeder::class);
        $days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

        foreach (['home', 'outdoor', 'gym'] as $environment) {
            foreach (['beginner', 'intermediate', 'advanced'] as $level) {
                foreach ([1, 3, 6] as $dayCount) {
                    $user = $this->userWithProfile([
                        'workout_preference' => $environment,
                        'fitness_level' => $level,
                        'low_impact_only' => true,
                        'availability_days' => array_slice($days, 0, $dayCount),
                    ]);

                    $result = app(RecommendationEngine::class)->generate($user);
                    $ids = collect($result['workouts'])->pluck('exercises')->flatten(1)->pluck('exercise_id');

                    $this->assertSame(
                        0,
                        Exercise::whereIn('id', $ids)->where('impact_level', '!=', 'low')->count(),
                        "{$environment}/{$level}/{$dayCount} days contains a non-low-impact exercise"
                    );
                }
            }
        }
    }

    public function test_unresolved_slots_are_reported_when_low_impact_leaves_no_candidate(): void
    {
        $this->gymKneeExercise('high');
        $user = $this->userWithProfile(['low_impact_only' => true]);

        $meta = app(RecommendationEngine::class)->generate($user)['meta'];

        $this->assertNotEmpty($meta['unresolved_slots']);
        $this->assertContains(
            ['knee_dominant', 'full_body'],
            array_column($meta['unresolved_slots'], 'patterns')
        );
    }

    public function test_profile_accepts_validates_and_returns_low_impact_flag(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/profile', [
            'age' => 30, 'height_cm' => 170, 'weight_kg' => 90, 'gender' => 'male',
            'goal' => 'lose_weight', 'fitness_level' => 'beginner',
            'workout_preference' => 'home', 'low_impact_only' => true,
            'availability_days' => ['monday'],
        ])->assertCreated()->assertJsonPath('data.low_impact_only', true);
        // The acting user instance cached a null profile relation in store().
        $user->unsetRelation('profile');
        $this->putJson('/api/profile', ['low_impact_only' => 'nope'])->assertUnprocessable();
        $this->putJson('/api/profile', ['low_impact_only' => false])
            ->assertOk()->assertJsonPath('data.low_impact_only', false);
    }

    public function test_changing_low_impact_invalidates_generated_plans_but_resending_same_value_does_not(): void
    {
        $user = $this->userWithProfile();
        Sanctum::actingAs($user);
        Workout::create([
            'user_id' => $user->id, 'name' => 'Plan', 'day_of_week' => 1,
            'estimated_duration_minutes' => 20, 'exercises' => [], 'is_generated' => true,
        ]);

        $this->putJson('/api/profile', ['low_impact_only' => false])->assertOk();
        $this->assertDatabaseHas('workouts', ['user_id' => $user->id, 'is_generated' => true]);

        $this->putJson('/api/profile', ['low_impact_only' => true])->assertOk();
        $this->assertDatabaseMissing('workouts', ['user_id' => $user->id, 'is_generated' => true]);
    }

    public function test_customization_rejects_non_low_impact_exercises_when_enabled(): void
    {
        $user = $this->userWithProfile(['low_impact_only' => true]);
        $high = $this->gymKneeExercise('high');
        $moderate = $this->gymKneeExercise('moderate');
        $low = $this->gymKneeExercise('low');
        $workout = Workout::create([
            'user_id' => $user->id, 'name' => 'Plan', 'exercises' => [], 'is_generated' => true,
        ]);
        Sanctum::actingAs($user);

        foreach ([$high, $moderate] as $exercise) {
            $this->putJson("/api/workouts/{$workout->id}/exercises", ['exercise_ids' => [$exercise->id]])
                ->assertUnprocessable()
                ->assertJsonPath('message', 'An exercise is not low-impact.');
        }

        $this->putJson("/api/workouts/{$workout->id}/exercises", ['exercise_ids' => [$low->id]])->assertOk();

        // Turning the setting off restores the full catalog.
        $user->profile->update(['low_impact_only' => false]);
        $this->putJson("/api/workouts/{$workout->id}/exercises", ['exercise_ids' => [$high->id]])->assertOk();
    }
}
