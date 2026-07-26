<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use App\Models\Profile;
use App\Models\User;
use App\Services\RecommendationEngine;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Property Test: Recommendation Differentiation by Goal and Level (Property 13)
 *
 * For pairs of profiles differing only in goal OR only in fitness_level,
 * verify generated plans differ in at least one aspect (exercise selection,
 * rep range, set range, or rest range).
 *
 * **Validates: Requirements 8.7**
 */
class RecommendationDifferentiationTest extends TestCase
{
    use RefreshDatabase;

    private RecommendationEngine $engine;

    protected function setUp(): void
    {
        parent::setUp();
        $this->engine = new RecommendationEngine();
        $this->seedExercises();
    }

    /**
     * Property 13: Different goals produce different plans.
     *
     * For each pair of different goals (same fitness_level, same workout_preference,
     * same availability_days), verify at least one aspect differs across multiple
     * generations (to account for randomness).
     *
     * **Validates: Requirements 8.7**
     */
    public function test_different_goals_produce_different_plans(): void
    {
        $goals = ['lose_weight', 'build_muscle', 'stay_fit', 'increase_stamina'];

        // For each pair of different goals
        for ($i = 0; $i < count($goals); $i++) {
            for ($j = $i + 1; $j < count($goals); $j++) {
                $differenceFound = false;

                // Run multiple times to account for randomness
                for ($attempt = 0; $attempt < 5; $attempt++) {
                    $user1 = $this->createUserWithProfile([
                        'goal' => $goals[$i],
                        'fitness_level' => 'intermediate',
                        'workout_preference' => 'gym',
                        'availability_days' => ['monday', 'wednesday', 'friday'],
                    ]);

                    $user2 = $this->createUserWithProfile([
                        'goal' => $goals[$j],
                        'fitness_level' => 'intermediate',
                        'workout_preference' => 'gym',
                        'availability_days' => ['monday', 'wednesday', 'friday'],
                    ]);

                    $plan1 = $this->engine->generate($user1);
                    $plan2 = $this->engine->generate($user2);

                    if ($this->plansDiffer($plan1, $plan2)) {
                        $differenceFound = true;
                        break;
                    }
                }

                $this->assertTrue(
                    $differenceFound,
                    "Plans for goals '{$goals[$i]}' and '{$goals[$j]}' should differ in at least one aspect "
                    . "(exercise selection, rep range, set range, or rest range) across 5 generations"
                );
            }
        }
    }

    /**
     * Property 13: Different fitness levels produce different plans.
     *
     * For each pair of different fitness_levels (same goal, same workout_preference,
     * same availability_days), verify at least one aspect differs across multiple
     * generations (to account for randomness).
     *
     * **Validates: Requirements 8.7**
     */
    public function test_different_levels_produce_different_plans(): void
    {
        $levels = ['beginner', 'intermediate', 'advanced'];

        // For each pair of different levels
        for ($i = 0; $i < count($levels); $i++) {
            for ($j = $i + 1; $j < count($levels); $j++) {
                $differenceFound = false;

                // Run multiple times to account for randomness
                for ($attempt = 0; $attempt < 5; $attempt++) {
                    $user1 = $this->createUserWithProfile([
                        'goal' => 'build_muscle',
                        'fitness_level' => $levels[$i],
                        'workout_preference' => 'gym',
                        'availability_days' => ['monday', 'wednesday', 'friday'],
                    ]);

                    $user2 = $this->createUserWithProfile([
                        'goal' => 'build_muscle',
                        'fitness_level' => $levels[$j],
                        'workout_preference' => 'gym',
                        'availability_days' => ['monday', 'wednesday', 'friday'],
                    ]);

                    $plan1 = $this->engine->generate($user1);
                    $plan2 = $this->engine->generate($user2);

                    if ($this->plansDiffer($plan1, $plan2)) {
                        $differenceFound = true;
                        break;
                    }
                }

                $this->assertTrue(
                    $differenceFound,
                    "Plans for levels '{$levels[$i]}' and '{$levels[$j]}' should differ in at least one aspect "
                    . "(exercise selection, rep range, set range, or rest range) across 5 generations"
                );
            }
        }
    }

    /**
     * Determine if two plans differ in at least one aspect:
     * - Exercise selection (different exercise IDs)
     * - Average rep range
     * - Average set range
     * - Average rest range
     */
    private function plansDiffer(array $plan1, array $plan2): bool
    {
        $stats1 = $this->extractPlanStats($plan1);
        $stats2 = $this->extractPlanStats($plan2);

        // Check if exercise selections differ
        if ($stats1['exercise_ids'] !== $stats2['exercise_ids']) {
            return true;
        }

        // Check if average sets differ (tolerance of 0.01 for floating point)
        if (abs($stats1['avg_sets'] - $stats2['avg_sets']) > 0.01) {
            return true;
        }

        // Check if average reps differ
        if (abs($stats1['avg_reps'] - $stats2['avg_reps']) > 0.01) {
            return true;
        }

        // Check if average rest differs
        if (abs($stats1['avg_rest'] - $stats2['avg_rest']) > 0.01) {
            return true;
        }

        return false;
    }

    /**
     * Extract statistical summary from a plan for comparison.
     */
    private function extractPlanStats(array $plan): array
    {
        $exerciseIds = [];
        $allSets = [];
        $allReps = [];
        $allRest = [];

        foreach ($plan['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $exerciseIds[] = $exercise['exercise_id'];
                $allSets[] = $exercise['sets'];
                $allReps[] = $exercise['reps'];
                $allRest[] = $exercise['rest_seconds'];
            }
        }

        sort($exerciseIds);

        return [
            'exercise_ids' => $exerciseIds,
            'avg_sets' => count($allSets) > 0 ? array_sum($allSets) / count($allSets) : 0,
            'avg_reps' => count($allReps) > 0 ? array_sum($allReps) / count($allReps) : 0,
            'avg_rest' => count($allRest) > 0 ? array_sum($allRest) / count($allRest) : 0,
        ];
    }

    /**
     * Create a user with a profile using the given data.
     */
    private function createUserWithProfile(array $profileData): User
    {
        $user = User::factory()->create();

        $defaults = [
            'user_id' => $user->id,
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
            'bmi' => 22.86,
        ];

        Profile::create(array_merge($defaults, $profileData));

        return $user->fresh(['profile']);
    }

    /**
     * Seed exercises into the database for testing.
     */
    private function seedExercises(): void
    {
        $this->artisan('db:seed', ['--class' => 'Database\\Seeders\\ExerciseSeeder']);
    }
}
