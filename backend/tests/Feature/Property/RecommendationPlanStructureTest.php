<?php

namespace Tests\Feature\Property;

use App\Models\User;
use App\Models\Profile;
use App\Services\RecommendationEngine;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Property Test: Recommendation Plan Structure Invariants (Property 11)
 *
 * For any valid user profile, the RecommendationEngine SHALL produce a Weekly_Plan where:
 * (a) there is exactly one workout for each day in the user's availability_days,
 * (b) each workout contains between 4 and 8 exercises,
 * (c) each exercise has sets in range 2–5, reps in range 5–20, and rest_seconds in range 30–120.
 *
 * **Validates: Requirements 8.1**
 */
class RecommendationPlanStructureTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->artisan('db:seed', ['--class' => 'Database\\Seeders\\ExerciseSeeder']);
    }

    /**
     * Property 11: Recommendation Plan Structure Invariants
     *
     * For random valid profiles, verify:
     * 1. Number of workouts = count(availability_days)
     * 2. Each workout has 4-8 exercises
     * 3. Each exercise has sets in 2-5
     * 4. Each exercise has reps in 5-20
     * 5. Each exercise has rest_seconds in 30-120
     *
     * **Validates: Requirements 8.1**
     */
    public function test_plan_structure_invariants_property(): void
    {
        $allDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        $goals = ['lose_weight', 'build_muscle', 'stay_fit', 'increase_stamina'];
        $fitnessLevels = ['beginner', 'intermediate', 'advanced'];
        $workoutPreferences = ['home', 'gym', 'outdoor'];

        $engine = new RecommendationEngine();

        for ($i = 0; $i < 50; $i++) {
            // Generate random availability days (1-7 days)
            $numDays = mt_rand(1, 7);
            $shuffledDays = $allDays;
            shuffle($shuffledDays);
            $availabilityDays = array_slice($shuffledDays, 0, $numDays);

            // Random goal, fitness level, and workout preference
            $goal = $goals[mt_rand(0, count($goals) - 1)];
            $fitnessLevel = $fitnessLevels[mt_rand(0, count($fitnessLevels) - 1)];
            $workoutPreference = $workoutPreferences[mt_rand(0, count($workoutPreferences) - 1)];

            // Create a fresh user with profile for each iteration
            $user = User::factory()->create();
            Profile::create([
                'user_id' => $user->id,
                'age' => mt_rand(13, 120),
                'height_cm' => mt_rand(500, 3000) / 10,
                'weight_kg' => mt_rand(200, 5000) / 10,
                'gender' => ['male', 'female', 'other'][mt_rand(0, 2)],
                'goal' => $goal,
                'fitness_level' => $fitnessLevel,
                'workout_preference' => $workoutPreference,
                'availability_days' => $availabilityDays,
                'bmi' => 22.0,
            ]);

            // Reload user with profile relationship
            $user->load('profile');

            // Generate plan
            $plan = $engine->generate($user);

            $context = "Iteration $i: goal=$goal, level=$fitnessLevel, preference=$workoutPreference, days=" . implode(',', $availabilityDays);

            // Invariant 1: Number of workouts equals count of availability days
            $this->assertCount(
                count($availabilityDays),
                $plan['workouts'],
                "$context — Expected " . count($availabilityDays) . " workouts but got " . count($plan['workouts'])
            );

            foreach ($plan['workouts'] as $workoutIndex => $workout) {
                $workoutContext = "$context, workout #$workoutIndex ('{$workout['name']}')";

                // Invariant 2: Each workout has 4-8 exercises
                $exerciseCount = count($workout['exercises']);
                $this->assertGreaterThanOrEqual(
                    4,
                    $exerciseCount,
                    "$workoutContext — Expected at least 4 exercises but got $exerciseCount"
                );
                $this->assertLessThanOrEqual(
                    8,
                    $exerciseCount,
                    "$workoutContext — Expected at most 8 exercises but got $exerciseCount"
                );

                foreach ($workout['exercises'] as $exerciseIndex => $exercise) {
                    $exerciseContext = "$workoutContext, exercise #$exerciseIndex";

                    // Invariant 3: Sets in range 2-5
                    $this->assertGreaterThanOrEqual(
                        2,
                        $exercise['sets'],
                        "$exerciseContext — Sets ({$exercise['sets']}) below minimum 2"
                    );
                    $this->assertLessThanOrEqual(
                        5,
                        $exercise['sets'],
                        "$exerciseContext — Sets ({$exercise['sets']}) above maximum 5"
                    );

                    // Invariant 4: Reps in range 5-20
                    $this->assertGreaterThanOrEqual(
                        5,
                        $exercise['reps'],
                        "$exerciseContext — Reps ({$exercise['reps']}) below minimum 5"
                    );
                    $this->assertLessThanOrEqual(
                        20,
                        $exercise['reps'],
                        "$exerciseContext — Reps ({$exercise['reps']}) above maximum 20"
                    );

                    // Invariant 5: Rest seconds in range 30-120
                    $this->assertGreaterThanOrEqual(
                        30,
                        $exercise['rest_seconds'],
                        "$exerciseContext — Rest seconds ({$exercise['rest_seconds']}) below minimum 30"
                    );
                    $this->assertLessThanOrEqual(
                        120,
                        $exercise['rest_seconds'],
                        "$exerciseContext — Rest seconds ({$exercise['rest_seconds']}) above maximum 120"
                    );
                }
            }
        }
    }
}
