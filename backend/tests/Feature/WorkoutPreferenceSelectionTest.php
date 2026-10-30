<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use App\Services\RecommendationEngine;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WorkoutPreferenceSelectionTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Create a gym profile with a single available day so the split is a
     * single full-body workout whose slots exercise the OR-pool logic.
     */
    private function gymUser(string $fitnessLevel = 'intermediate', string $goal = 'stay_fit'): User
    {
        $user = User::factory()->create();
        $user->profile()->create([
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => $goal,
            'fitness_level' => $fitnessLevel,
            'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ]);

        return $user->load('profile');
    }

    private function seedBalancedGymCatalog(): void
    {
        // One exercise per movement pattern so every full-body slot resolves.
        $patterns = [
            'knee_dominant' => ['quadriceps'],
            'hip_dominant' => ['hamstrings'],
            'horizontal_push' => ['chest'],
            'horizontal_pull' => ['back'],
            'vertical_pull' => ['back'],
            'vertical_push' => ['shoulders'],
            'core' => ['core'],
        ];

        foreach ($patterns as $pattern => $primary) {
            Exercise::factory()->create([
                'name' => "Primary {$pattern}",
                'movement_pattern' => $pattern,
                'equipment' => 'dumbbell',
                'environments' => ['gym'],
                'difficulty' => 'intermediate',
                'primary_muscles' => $primary,
                'exercise_type' => 'compound',
            ]);
        }
    }

    public function test_preferred_accessory_exercise_appears_even_when_in_a_lower_priority_pool(): void
    {
        $this->seedBalancedGymCatalog();

        // The full-body "vertical_push OR accessory" slot would normally pick a
        // vertical_push exercise first. A preferred accessory exercise must
        // still surface despite living in the lower-priority pool.
        $preferred = Exercise::factory()->create([
            'name' => 'Preferred Accessory',
            'movement_pattern' => 'accessory',
            'equipment' => 'dumbbell',
            'environments' => ['gym'],
            'difficulty' => 'intermediate',
            'primary_muscles' => ['biceps'],
            'exercise_type' => 'isolation',
        ]);

        $user = $this->gymUser();

        $result = app(RecommendationEngine::class)->generate(
            $user,
            includedExerciseIds: [$preferred->id],
        );

        $ids = collect($result['workouts'])
            ->pluck('exercises')
            ->flatten(1)
            ->pluck('exercise_id');

        $this->assertContains(
            $preferred->id,
            $ids->all(),
            'Preferred exercise in a lower-priority OR-pool should appear in the plan.'
        );
    }

    public function test_excluded_exercise_is_never_prescribed(): void
    {
        // Two horizontal_push options; exclude one and leave only the other.
        $excluded = Exercise::factory()->create([
            'name' => 'Excluded Push',
            'movement_pattern' => 'horizontal_push',
            'equipment' => 'dumbbell',
            'environments' => ['gym'],
            'difficulty' => 'intermediate',
            'primary_muscles' => ['chest'],
        ]);
        Exercise::factory()->create([
            'name' => 'Allowed Push',
            'movement_pattern' => 'horizontal_push',
            'equipment' => 'dumbbell',
            'environments' => ['gym'],
            'difficulty' => 'intermediate',
            'primary_muscles' => ['chest'],
        ]);
        $this->seedBalancedGymCatalog();

        $user = $this->gymUser();

        $result = app(RecommendationEngine::class)->generate(
            $user,
            excludedExerciseIds: [$excluded->id],
        );

        $ids = collect($result['workouts'])
            ->pluck('exercises')
            ->flatten(1)
            ->pluck('exercise_id');

        $this->assertNotContains(
            $excluded->id,
            $ids->all(),
            'Excluded exercise must never appear in the generated plan.'
        );
    }

    public function test_preference_respects_training_location_and_fitness_level(): void
    {
        // A preferred exercise that is ineligible for the member's environment
        // (gym-only here, but the member trains at home) must not be forced in,
        // because environment eligibility is a hard safety filter.
        $gymOnlyPreferred = Exercise::factory()->create([
            'name' => 'Gym Only Preferred',
            'movement_pattern' => 'horizontal_push',
            'equipment' => 'barbell',
            'environments' => ['gym'],
            'difficulty' => 'advanced',
            'primary_muscles' => ['chest'],
        ]);

        // A home-eligible, equipment-free, beginner-appropriate catalog.
        foreach ([
            'knee_dominant' => ['quadriceps'],
            'hip_dominant' => ['hamstrings'],
            'horizontal_push' => ['chest'],
            'horizontal_pull' => ['back'],
            'vertical_pull' => ['back'],
            'core' => ['core'],
            'accessory' => ['biceps'],
        ] as $pattern => $primary) {
            Exercise::factory()->create([
                'name' => "Home {$pattern}",
                'movement_pattern' => $pattern,
                'equipment' => 'bodyweight',
                'environments' => ['home', 'gym', 'outdoor'],
                'difficulty' => 'beginner',
                'primary_muscles' => $primary,
            ]);
        }

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
        $user->load('profile');

        $result = app(RecommendationEngine::class)->generate(
            $user,
            includedExerciseIds: [$gymOnlyPreferred->id],
        );

        $selectedIds = collect($result['workouts'])
            ->pluck('exercises')
            ->flatten(1)
            ->pluck('exercise_id');

        $this->assertNotContains(
            $gymOnlyPreferred->id,
            $selectedIds->all(),
            'A gym-only preferred exercise must not appear in a home plan.'
        );

        // Every selected exercise must be home-eligible and equipment-free.
        Exercise::whereIn('id', $selectedIds)->get()->each(function (Exercise $e): void {
            $this->assertContains('home', $e->environments, $e->name);
            $this->assertSame('bodyweight', $e->equipment, $e->name);
        });
    }

    public function test_generate_endpoint_excludes_requested_exercise(): void
    {
        $excluded = Exercise::factory()->create([
            'name' => 'Endpoint Excluded Push',
            'movement_pattern' => 'horizontal_push',
            'equipment' => 'dumbbell',
            'environments' => ['gym'],
            'difficulty' => 'intermediate',
            'primary_muscles' => ['chest'],
        ]);
        Exercise::factory()->create([
            'name' => 'Endpoint Allowed Push',
            'movement_pattern' => 'horizontal_push',
            'equipment' => 'dumbbell',
            'environments' => ['gym'],
            'difficulty' => 'intermediate',
            'primary_muscles' => ['chest'],
        ]);
        $this->seedBalancedGymCatalog();

        $user = $this->gymUser();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate', [
            'excluded_exercises' => [$excluded->id],
        ])->assertCreated();

        $ids = collect($response->json('data'))
            ->pluck('exercises')
            ->flatten(1)
            ->pluck('exercise_id');

        $this->assertNotContains($excluded->id, $ids->all());
    }
}
