<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Property Test: Exercise Filter Correctness (Property 10)
 *
 * For random filter combinations (muscle_group, difficulty, equipment),
 * verify every returned exercise matches ALL provided filters.
 *
 * **Validates: Requirements 7.2**
 */
class ExerciseFilterCorrectnessTest extends TestCase
{
    use RefreshDatabase;

    private const MUSCLE_GROUPS = [
        'chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'core', 'full_body',
    ];

    private const DIFFICULTIES = [
        'beginner', 'intermediate', 'advanced',
    ];

    private const EQUIPMENT = [
        'bodyweight', 'dumbbell', 'barbell', 'kettlebell', 'resistance_band', 'machine', 'pull_up_bar',
    ];

    /**
     * Property 10: Exercise Filter Correctness
     *
     * Generate random filter combinations, verify every returned exercise
     * matches ALL provided filters simultaneously.
     *
     * **Validates: Requirements 7.2**
     */
    public function test_exercise_filter_correctness_property(): void
    {
        // Seed exercises covering all combinations to ensure filter results are non-trivial
        Exercise::factory()->count(60)->create();

        $user = User::factory()->create();
        Sanctum::actingAs($user);

        for ($i = 0; $i < 100; $i++) {
            // Pick random number of filters (0 to 3)
            $filterCount = mt_rand(0, 3);

            $filters = [];
            $queryParams = [];

            // Build random filter combination
            $availableFilters = ['muscle_group', 'difficulty', 'equipment'];
            shuffle($availableFilters);
            $selectedFilters = array_slice($availableFilters, 0, $filterCount);

            foreach ($selectedFilters as $filterType) {
                switch ($filterType) {
                    case 'muscle_group':
                        $value = self::MUSCLE_GROUPS[array_rand(self::MUSCLE_GROUPS)];
                        $filters['muscle_group'] = $value;
                        $queryParams['muscle_group'] = $value;
                        break;
                    case 'difficulty':
                        $value = self::DIFFICULTIES[array_rand(self::DIFFICULTIES)];
                        $filters['difficulty'] = $value;
                        $queryParams['difficulty'] = $value;
                        break;
                    case 'equipment':
                        $value = self::EQUIPMENT[array_rand(self::EQUIPMENT)];
                        $filters['equipment'] = $value;
                        $queryParams['equipment'] = $value;
                        break;
                }
            }

            // Build query string
            $queryString = http_build_query($queryParams);
            $url = '/api/exercises' . ($queryString ? '?' . $queryString : '');

            // Request with large page size to get all results
            $response = $this->getJson($url . ($queryString ? '&' : '?') . 'page_size=100');

            $response->assertStatus(200);

            $data = $response->json('data');
            $exercises = $data['exercises'];

            // Verify every returned exercise matches ALL provided filters
            foreach ($exercises as $index => $exercise) {
                if (isset($filters['muscle_group'])) {
                    $this->assertEquals(
                        $filters['muscle_group'],
                        $exercise['muscle_group'],
                        "Iteration $i, exercise $index: muscle_group filter '{$filters['muscle_group']}' not matched. Got '{$exercise['muscle_group']}'"
                    );
                }

                if (isset($filters['difficulty'])) {
                    $this->assertEquals(
                        $filters['difficulty'],
                        $exercise['difficulty'],
                        "Iteration $i, exercise $index: difficulty filter '{$filters['difficulty']}' not matched. Got '{$exercise['difficulty']}'"
                    );
                }

                if (isset($filters['equipment'])) {
                    $this->assertEquals(
                        $filters['equipment'],
                        $exercise['equipment'],
                        "Iteration $i, exercise $index: equipment filter '{$filters['equipment']}' not matched. Got '{$exercise['equipment']}'"
                    );
                }
            }

            // Additionally verify that the result count matches what the database would produce
            $expectedQuery = Exercise::query();
            if (isset($filters['muscle_group'])) {
                $expectedQuery->where('muscle_group', $filters['muscle_group']);
            }
            if (isset($filters['difficulty'])) {
                $expectedQuery->where('difficulty', $filters['difficulty']);
            }
            if (isset($filters['equipment'])) {
                $expectedQuery->where('equipment', $filters['equipment']);
            }
            $expectedCount = $expectedQuery->count();

            $this->assertEquals(
                $expectedCount,
                $data['pagination']['total_count'],
                "Iteration $i: total_count mismatch for filters " . json_encode($filters) . ". Expected $expectedCount, got {$data['pagination']['total_count']}"
            );
        }
    }
}
