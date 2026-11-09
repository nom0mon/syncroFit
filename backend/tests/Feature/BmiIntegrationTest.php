<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Covers all BMI-related rules introduced in bmi_status_integration_strategy.md:
 *
 *  Section 1 — Input constraints (height 54–272 cm, weight 2–635 kg)
 *  Section 2 — Dynamic goal filtering based on BMI category
 *  Section 3 — Prescription modifiers: set cap, low-impact, rest buffer, compound bias
 */
class BmiIntegrationTest extends TestCase
{
    use RefreshDatabase;

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /** Base availability days used by generation tests. */
    private array $days = ['monday'];

    /**
     * Create and authenticate a user whose profile produces the given BMI.
     * height_cm and weight_kg are chosen so that BMI = weight / (height/100)^2
     * falls in the desired category.
     */
    private function userWithBmi(float $bmi, string $goal = 'build_muscle', string $fitnessLevel = 'intermediate'): User
    {
        $user = User::factory()->create();
        // Fix height at 170 cm and derive weight for the desired BMI.
        $height = 170;
        $weight = round($bmi * pow($height / 100, 2), 2);

        $user->profile()->create([
            'age'               => 25,
            'height_cm'         => $height,
            'weight_kg'         => $weight,
            'gender'            => 'male',
            'goal'              => $goal,
            'fitness_level'     => $fitnessLevel,
            'workout_preference'=> 'gym',
            'availability_days' => $this->days,
            'bmi'               => $bmi,
        ]);

        return $user;
    }

    /**
     * Create a minimal gym exercise that can be returned by the engine.
     * Returns a compound exercise by default (used by compound-bias tests).
     */
    private function makeGymExercise(array $overrides = []): Exercise
    {
        return Exercise::factory()->create(array_merge([
            'muscle_group'       => 'chest',
            'equipment'          => 'barbell',
            'environments'       => ['gym'],
            'difficulty'         => 'intermediate',
            'exercise_type'      => 'compound',
            'impact_level'       => 'high',
            'movement_pattern'   => 'horizontal_push',
            'default_duration_seconds' => 0,
        ], $overrides));
    }

    /** Create a low-impact gym exercise (used by low-impact enforcement tests). */
    private function makeLowImpactExercise(array $overrides = []): Exercise
    {
        return Exercise::factory()->create(array_merge([
            'muscle_group'       => 'chest',
            'equipment'          => 'dumbbell',
            'environments'       => ['gym'],
            'difficulty'         => 'intermediate',
            'exercise_type'      => 'compound',
            'impact_level'       => 'low',
            'movement_pattern'   => 'horizontal_push',
            'default_duration_seconds' => 0,
        ], $overrides));
    }

    // =========================================================================
    // Section 1 — Input constraints
    // =========================================================================

    /** @test */
    public function height_below_minimum_human_record_is_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // 53 cm is below the 54 cm minimum (Chandra Bahadur Dangi record).
        $this->postJson('/api/profile', [
            'age'               => 25,
            'height_cm'         => 53,
            'weight_kg'         => 70,
            'gender'            => 'male',
            'goal'              => 'build_muscle',
            'fitness_level'     => 'intermediate',
            'workout_preference'=> 'gym',
            'availability_days' => ['monday'],
        ])->assertStatus(422)
          ->assertJsonValidationErrors(['height_cm']);
    }

    /** @test */
    public function height_above_maximum_human_record_is_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // 273 cm exceeds Robert Wadlow's 272 cm.
        $this->postJson('/api/profile', [
            'age'               => 25,
            'height_cm'         => 273,
            'weight_kg'         => 70,
            'gender'            => 'male',
            'goal'              => 'build_muscle',
            'fitness_level'     => 'intermediate',
            'workout_preference'=> 'gym',
            'availability_days' => ['monday'],
        ])->assertStatus(422)
          ->assertJsonValidationErrors(['height_cm']);
    }

    /** @test */
    public function weight_below_minimum_human_record_is_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // 1 kg is below the 2 kg minimum (Lucía Zárate record).
        $this->postJson('/api/profile', [
            'age'               => 25,
            'height_cm'         => 170,
            'weight_kg'         => 1,
            'gender'            => 'male',
            'goal'              => 'build_muscle',
            'fitness_level'     => 'intermediate',
            'workout_preference'=> 'gym',
            'availability_days' => ['monday'],
        ])->assertStatus(422)
          ->assertJsonValidationErrors(['weight_kg']);
    }

    /** @test */
    public function weight_above_maximum_human_record_is_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // 636 kg exceeds Jon Brower Minnoch's 635 kg.
        $this->postJson('/api/profile', [
            'age'               => 25,
            'height_cm'         => 170,
            'weight_kg'         => 636,
            'gender'            => 'male',
            'goal'              => 'build_muscle',
            'fitness_level'     => 'intermediate',
            'workout_preference'=> 'gym',
            'availability_days' => ['monday'],
        ])->assertStatus(422)
          ->assertJsonValidationErrors(['weight_kg']);
    }

    /** @test */
    public function boundary_height_values_at_54_and_272_are_accepted(): void
    {
        // Lower boundary
        $userA = User::factory()->create();
        Sanctum::actingAs($userA);
        $this->postJson('/api/profile', [
            'age' => 25, 'height_cm' => 54, 'weight_kg' => 10,
            'gender' => 'male', 'goal' => 'build_muscle',
            'fitness_level' => 'beginner', 'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ])->assertStatus(201);

        // Upper boundary
        $userB = User::factory()->create();
        Sanctum::actingAs($userB);
        $this->postJson('/api/profile', [
            'age' => 25, 'height_cm' => 272, 'weight_kg' => 70,
            'gender' => 'male', 'goal' => 'build_muscle',
            'fitness_level' => 'beginner', 'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ])->assertStatus(201);
    }

    /** @test */
    public function boundary_weight_values_at_2_and_635_are_accepted(): void
    {
        // Lower boundary — 2 kg
        $userA = User::factory()->create();
        Sanctum::actingAs($userA);
        $this->postJson('/api/profile', [
            'age' => 25, 'height_cm' => 170, 'weight_kg' => 2,
            'gender' => 'male', 'goal' => 'build_muscle',
            'fitness_level' => 'beginner', 'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ])->assertStatus(201);

        // Upper boundary — 635 kg
        $userB = User::factory()->create();
        Sanctum::actingAs($userB);
        $this->postJson('/api/profile', [
            'age' => 25, 'height_cm' => 170, 'weight_kg' => 635,
            'gender' => 'male', 'goal' => 'build_muscle',
            'fitness_level' => 'beginner', 'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ])->assertStatus(201);
    }

    /** @test */
    public function update_profile_also_enforces_height_and_weight_bounds(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $user->profile()->create([
            'age' => 25, 'height_cm' => 170, 'weight_kg' => 70,
            'gender' => 'male', 'goal' => 'build_muscle',
            'fitness_level' => 'intermediate', 'workout_preference' => 'gym',
            'availability_days' => ['monday'], 'bmi' => 24.2,
        ]);

        // Too short
        $this->putJson('/api/profile', ['height_cm' => 10])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['height_cm']);

        // Too heavy
        $this->putJson('/api/profile', ['weight_kg' => 700])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['weight_kg']);
    }

    // =========================================================================
    // Section 2 — Dynamic goal filtering
    // =========================================================================

    /** @test */
    public function underweight_user_cannot_generate_with_lose_weight_goal(): void
    {
        // BMI 16 = underweight; lose_weight is blocked.
        $user = $this->userWithBmi(16.0, 'build_muscle');
        $this->makeGymExercise();
        Sanctum::actingAs($user);

        $this->postJson('/api/workouts/generate', ['goal' => 'lose_weight'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['goal']);
    }

    /** @test */
    public function underweight_user_cannot_generate_with_stay_fit_goal(): void
    {
        $user = $this->userWithBmi(16.0, 'build_muscle');
        $this->makeGymExercise();
        Sanctum::actingAs($user);

        $this->postJson('/api/workouts/generate', ['goal' => 'stay_fit'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['goal']);
    }

    /** @test */
    public function underweight_user_can_generate_with_build_muscle_goal(): void
    {
        $user = $this->userWithBmi(16.0, 'build_muscle');
        $this->makeGymExercise();
        Sanctum::actingAs($user);

        $this->postJson('/api/workouts/generate')
            ->assertCreated()
            ->assertJsonPath('success', true);
    }

    /** @test */
    public function underweight_user_can_generate_with_increase_stamina_goal(): void
    {
        $user = $this->userWithBmi(16.0, 'increase_stamina');
        $this->makeGymExercise();
        Sanctum::actingAs($user);

        $this->postJson('/api/workouts/generate')
            ->assertCreated()
            ->assertJsonPath('success', true);
    }

    /** @test */
    public function healthy_bmi_user_can_generate_with_any_goal(): void
    {
        // BMI 22 = healthy; all four goals allowed.
        foreach (['lose_weight', 'build_muscle', 'stay_fit', 'increase_stamina'] as $goal) {
            $user = $this->userWithBmi(22.0, $goal);
            $this->makeGymExercise();
            Sanctum::actingAs($user);

            $this->postJson('/api/workouts/generate')
                ->assertCreated()
                ->assertJsonPath('success', true);
        }
    }

    /** @test */
    public function overweight_user_cannot_generate_with_stay_fit_goal(): void
    {
        // BMI 27 = overweight; stay_fit is blocked.
        $user = $this->userWithBmi(27.0, 'lose_weight');
        $this->makeGymExercise();
        Sanctum::actingAs($user);

        $this->postJson('/api/workouts/generate', ['goal' => 'stay_fit'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['goal']);
    }

    /** @test */
    public function obese_user_cannot_generate_with_stay_fit_goal(): void
    {
        // BMI 35 = obese; stay_fit is blocked.
        $user = $this->userWithBmi(35.0, 'lose_weight');
        $this->makeLowImpactExercise(); // obese → low-impact enforced
        Sanctum::actingAs($user);

        $this->postJson('/api/workouts/generate', ['goal' => 'stay_fit'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['goal']);
    }

    /** @test */
    public function overweight_user_can_generate_with_allowed_goals(): void
    {
        // BMI 27 = overweight; lose_weight, build_muscle, increase_stamina allowed.
        foreach (['lose_weight', 'build_muscle', 'increase_stamina'] as $goal) {
            $user = $this->userWithBmi(27.0, $goal);
            $this->makeGymExercise();
            Sanctum::actingAs($user);

            $this->postJson('/api/workouts/generate')
                ->assertCreated()
                ->assertJsonPath('success', true);
        }
    }

    /** @test */
    public function goal_guard_uses_profile_goal_when_no_override_is_sent(): void
    {
        // Profile goal is 'stay_fit' but BMI is overweight — should be blocked
        // even without an explicit goal override in the request body.
        $user = $this->userWithBmi(27.0, 'stay_fit');
        $this->makeGymExercise();
        Sanctum::actingAs($user);

        $this->postJson('/api/workouts/generate')
            ->assertStatus(422)
            ->assertJsonValidationErrors(['goal']);
    }

    // =========================================================================
    // Section 3 — Prescription modifiers
    // =========================================================================

    /** @test */
    public function obese_user_receives_at_most_2_sets_per_exercise_regardless_of_fitness_level(): void
    {
        // BMI 35 = obese; advanced user would normally get 3 sets → capped to 2.
        $user = $this->userWithBmi(35.0, 'build_muscle', 'advanced');
        $this->makeLowImpactExercise();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate')->assertCreated();

        foreach ($response->json('data') as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertLessThanOrEqual(2, $exercise['sets'],
                    "Obese user received {$exercise['sets']} sets — expected ≤ 2.");
            }
        }
    }

    /** @test */
    public function overweight_user_receives_standard_set_count(): void
    {
        // BMI 27 = overweight; set cap only applies at obesity (BMI ≥ 30).
        // Intermediate user should get 3 sets normally.
        $user = $this->userWithBmi(27.0, 'build_muscle', 'intermediate');
        $this->makeGymExercise();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate')->assertCreated();

        $foundThreeSets = false;
        foreach ($response->json('data') as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                if ($exercise['sets'] === 3) {
                    $foundThreeSets = true;
                }
            }
        }
        $this->assertTrue($foundThreeSets,
            'Overweight (not obese) intermediate user should still get 3 sets.');
    }

    /** @test */
    public function overweight_user_receives_extra_30_seconds_rest(): void
    {
        // BMI 27 = overweight.
        // lose_weight + non-compound default rest = 90 s → with +30 buffer = 120 s.
        $user = $this->userWithBmi(27.0, 'lose_weight', 'beginner');
        $this->makeGymExercise(['exercise_type' => 'isolation']);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate')->assertCreated();

        foreach ($response->json('data') as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                if ($exercise['duration_seconds'] === 0) {
                    $this->assertGreaterThanOrEqual(120, $exercise['rest_seconds'],
                        "Overweight user rest ({$exercise['rest_seconds']}s) should be ≥ 120s (90 base + 30 buffer).");
                }
            }
        }
    }

    /** @test */
    public function obese_user_receives_extra_30_seconds_rest(): void
    {
        // BMI 35 = obese. Rest buffer of +30 s must apply.
        $user = $this->userWithBmi(35.0, 'build_muscle', 'beginner');
        $this->makeLowImpactExercise(['exercise_type' => 'isolation']);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate')->assertCreated();

        foreach ($response->json('data') as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                if ($exercise['duration_seconds'] === 0) {
                    // build_muscle isolation base = 90 s → with +30 = 120 s minimum.
                    $this->assertGreaterThanOrEqual(120, $exercise['rest_seconds'],
                        "Obese user rest ({$exercise['rest_seconds']}s) should be ≥ 120s.");
                }
            }
        }
    }

    /** @test */
    public function healthy_bmi_user_does_not_receive_extra_rest(): void
    {
        // BMI 22 = healthy; no rest buffer applies.
        $user = $this->userWithBmi(22.0, 'lose_weight', 'beginner');
        $this->makeGymExercise(['exercise_type' => 'isolation']);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate')->assertCreated();

        foreach ($response->json('data') as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                if ($exercise['duration_seconds'] === 0) {
                    // lose_weight + isolation = 90 s exactly; no buffer.
                    $this->assertEquals(90, $exercise['rest_seconds'],
                        "Healthy user rest should be exactly 90s, got {$exercise['rest_seconds']}s.");
                }
            }
        }
    }

    /** @test */
    public function obese_user_generation_automatically_enforces_low_impact(): void
    {
        // BMI 35 = obese. A high-impact exercise should NOT appear in the plan;
        // the engine must pick the low-impact alternative.
        $user = $this->userWithBmi(35.0, 'build_muscle', 'intermediate');
        $this->makeGymExercise(['impact_level' => 'high']);      // should be excluded
        $this->makeLowImpactExercise(['impact_level' => 'low']); // should be selected
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate')->assertCreated();

        $exerciseIds = collect($response->json('data'))
            ->flatMap(fn ($w) => collect($w['exercises'])->pluck('exercise_id'))
            ->all();

        $highImpactIds = Exercise::where('impact_level', 'high')->pluck('id')->all();
        foreach ($exerciseIds as $id) {
            $this->assertNotContains($id, $highImpactIds,
                "Obese user plan must not contain high-impact exercises.");
        }
    }

    /** @test */
    public function goal_guard_error_message_lists_available_goals(): void
    {
        // Verify the 422 error body contains a helpful list of allowed goals.
        $user = $this->userWithBmi(27.0, 'lose_weight');
        $this->makeGymExercise();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/workouts/generate', ['goal' => 'stay_fit'])
            ->assertStatus(422);

        $errorMessage = $response->json('errors.goal.0') ?? '';
        $this->assertStringContainsStringIgnoringCase('lose weight', $errorMessage,
            'Error message should list allowed goals for the user.');
    }
}
