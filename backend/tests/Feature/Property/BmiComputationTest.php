<?php

namespace Tests\Feature\Property;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Property Test: BMI Computation Correctness (Property 8)
 *
 * For random valid height_cm (50-300) and weight_kg (20-500),
 * verify computed BMI equals weight_kg / (height_cm / 100)^2 rounded to 2 decimals.
 *
 * **Validates: Requirements 6.1, 6.5**
 */
class BmiComputationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Property 8: BMI Computation Correctness — Profile Creation
     *
     * Generate random valid height_cm (50–300) and weight_kg (20–500),
     * create a profile via POST /api/profile, and verify the returned BMI
     * equals weight_kg / (height_cm / 100)^2 rounded to 2 decimals.
     *
     * **Validates: Requirements 6.1, 6.5**
     */
    public function test_bmi_computation_correctness_on_creation_property(): void
    {
        for ($i = 0; $i < 100; $i++) {
            // Generate random valid height and weight within spec bounds
            $heightCm = mt_rand(500, 3000) / 10; // 50.0 to 300.0
            $weightKg = mt_rand(200, 5000) / 10; // 20.0 to 500.0

            // Expected BMI formula: weight_kg / (height_cm / 100)^2 rounded to 2 decimals
            $expectedBmi = round($weightKg / pow($heightCm / 100, 2), 2);

            // Each iteration uses a fresh user (to avoid 409 duplicate profile)
            $user = User::factory()->create();
            Sanctum::actingAs($user);

            $response = $this->postJson('/api/profile', [
                'age' => mt_rand(13, 120),
                'height_cm' => $heightCm,
                'weight_kg' => $weightKg,
                'gender' => ['male', 'female', 'other'][mt_rand(0, 2)],
                'goal' => ['lose_weight', 'build_muscle', 'stay_fit', 'increase_stamina'][mt_rand(0, 3)],
                'fitness_level' => ['beginner', 'intermediate', 'advanced'][mt_rand(0, 2)],
                'workout_preference' => ['home', 'gym', 'outdoor'][mt_rand(0, 2)],
                'availability_days' => ['monday', 'tuesday', 'wednesday'],
            ]);

            $response->assertStatus(201);

            $returnedBmi = (float) $response->json('data.bmi');

            $this->assertEquals(
                $expectedBmi,
                $returnedBmi,
                "Iteration $i: BMI mismatch for height_cm=$heightCm, weight_kg=$weightKg. "
                . "Expected: $expectedBmi, Got: $returnedBmi"
            );
        }
    }

    /**
     * Property 8: BMI Computation Correctness — Profile Update
     *
     * Create a profile, then update with random valid height/weight values,
     * and verify the recomputed BMI matches the expected formula.
     *
     * **Validates: Requirements 6.1, 6.5**
     */
    public function test_bmi_computation_correctness_on_update_property(): void
    {
        for ($i = 0; $i < 100; $i++) {
            // Create a user with an initial profile
            $user = User::factory()->create();
            Sanctum::actingAs($user);

            $this->postJson('/api/profile', [
                'age' => 25,
                'height_cm' => 170.0,
                'weight_kg' => 70.0,
                'gender' => 'male',
                'goal' => 'stay_fit',
                'fitness_level' => 'intermediate',
                'workout_preference' => 'gym',
                'availability_days' => ['monday', 'wednesday', 'friday'],
            ])->assertStatus(201);

            // Generate random new height and weight for update
            $newHeightCm = mt_rand(500, 3000) / 10; // 50.0 to 300.0
            $newWeightKg = mt_rand(200, 5000) / 10; // 20.0 to 500.0

            $expectedBmi = round($newWeightKg / pow($newHeightCm / 100, 2), 2);

            $response = $this->putJson('/api/profile', [
                'height_cm' => $newHeightCm,
                'weight_kg' => $newWeightKg,
            ]);

            $response->assertStatus(200);

            $returnedBmi = (float) $response->json('data.bmi');

            $this->assertEquals(
                $expectedBmi,
                $returnedBmi,
                "Iteration $i: BMI mismatch on update for height_cm=$newHeightCm, weight_kg=$newWeightKg. "
                . "Expected: $expectedBmi, Got: $returnedBmi"
            );
        }
    }
}
