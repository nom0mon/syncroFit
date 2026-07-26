<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Property Test: Exercise List Ordering and Pagination Metadata (Property 9)
 *
 * For random page sizes, verify alphabetical ordering, correct current_page,
 * accurate total_count and total_pages.
 *
 * **Validates: Requirements 7.1**
 */
class ExercisePaginationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Property 9: Exercise List Ordering and Pagination Metadata
     *
     * Generate random page sizes, verify results are alphabetically ordered
     * and pagination metadata is accurate (current_page, total_count, total_pages).
     *
     * **Validates: Requirements 7.1**
     */
    public function test_exercise_list_ordering_and_pagination_metadata_property(): void
    {
        // Seed a fixed set of exercises for the property test
        $totalExercises = 47; // arbitrary non-round number
        Exercise::factory()->count($totalExercises)->create();

        $user = User::factory()->create();
        Sanctum::actingAs($user);

        for ($i = 0; $i < 100; $i++) {
            // Generate random page size between 1 and 50
            $pageSize = mt_rand(1, 50);

            // Calculate expected total pages
            $expectedTotalPages = (int) ceil($totalExercises / $pageSize);

            // Pick a random valid page
            $page = mt_rand(1, $expectedTotalPages);

            $response = $this->getJson("/api/exercises?page={$page}&page_size={$pageSize}");

            $response->assertStatus(200);

            $data = $response->json('data');
            $exercises = $data['exercises'];
            $pagination = $data['pagination'];

            // Verify current_page matches requested page
            $this->assertEquals(
                $page,
                $pagination['current_page'],
                "Iteration $i: current_page should be $page for page_size=$pageSize, got {$pagination['current_page']}"
            );

            // Verify total_count equals actual number of exercises
            $this->assertEquals(
                $totalExercises,
                $pagination['total_count'],
                "Iteration $i: total_count should be $totalExercises, got {$pagination['total_count']}"
            );

            // Verify total_pages equals ceil(total_count / page_size)
            $this->assertEquals(
                $expectedTotalPages,
                $pagination['total_pages'],
                "Iteration $i: total_pages should be $expectedTotalPages for page_size=$pageSize, got {$pagination['total_pages']}"
            );

            // Verify the number of items on this page is correct
            $expectedItemsOnPage = ($page < $expectedTotalPages)
                ? $pageSize
                : $totalExercises - ($pageSize * ($expectedTotalPages - 1));
            $this->assertCount(
                $expectedItemsOnPage,
                $exercises,
                "Iteration $i: page $page with page_size=$pageSize should have $expectedItemsOnPage items, got " . count($exercises)
            );

            // Verify exercises are in alphabetical order by name
            $names = array_map(fn($ex) => $ex['name'], $exercises);
            $sortedNames = $names;
            sort($sortedNames, SORT_STRING | SORT_FLAG_CASE);

            $this->assertEquals(
                $sortedNames,
                $names,
                "Iteration $i: exercises on page $page with page_size=$pageSize should be alphabetically ordered"
            );
        }
    }
}
