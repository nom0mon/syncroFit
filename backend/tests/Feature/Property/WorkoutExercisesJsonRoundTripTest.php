<?php

namespace Tests\Feature\Property;

use App\Models\User;
use App\Models\Workout;
use Eris\Generators;
use Eris\TestTrait;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Property Test: Workout exercises JSON round-trip (Property 2)
 *
 * Feature: database-simplification
 * Property 2: Workout exercises JSON round-trip
 *
 * For any valid array of exercise objects (each containing exercise_id, sets, reps,
 * duration_seconds, and order), storing the array in a Workout model's `exercises`
 * column and reading it back SHALL produce an identical array.
 *
 * **Validates: Requirements 3.2**
 */
class WorkoutExercisesJsonRoundTripTest extends TestCase
{
    use RefreshDatabase;
    use TestTrait;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::create([
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'testuser_' . uniqid() . '@example.com',
            'password' => bcrypt('password'),
        ]);
    }

    /**
     * Property 2: Workout exercises JSON round-trip
     *
     * Using Eris, generate arrays of exercise objects with exercise_id, sets, reps,
     * duration_seconds, order, store in Workout model and verify identical array on read-back.
     *
     * **Validates: Requirements 3.2**
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_workout_exercises_json_round_trip_property(): void
    {
        $this->limitTo(100);

        $this->forAll(
            $this->exercisesArrayGenerator()
        )->then(function (array $exercises): void {
            // Store the exercises array in a Workout model
            $workout = Workout::create([
                'user_id' => $this->user->id,
                'name' => 'Test Workout',
                'day_of_week' => 'Monday',
                'estimated_duration_minutes' => 30,
                'exercises' => $exercises,
                'is_generated' => false,
            ]);

            // Read the workout back from the database
            $retrieved = Workout::find($workout->id);

            // Verify the exercises array is identical on read-back
            $this->assertNotNull($retrieved, 'Workout should be retrievable from database');
            $this->assertEquals(
                $exercises,
                $retrieved->exercises,
                'Exercises array should be identical after JSON round-trip. ' .
                'Stored: ' . json_encode($exercises) . ' Retrieved: ' . json_encode($retrieved->exercises)
            );

            // Verify the count matches
            $this->assertCount(
                count($exercises),
                $retrieved->exercises,
                'Exercise count should match after round-trip'
            );

            // Verify each exercise object fields are preserved
            foreach ($exercises as $index => $exercise) {
                $retrievedExercise = $retrieved->exercises[$index];
                $this->assertEquals($exercise['exercise_id'], $retrievedExercise['exercise_id'],
                    "exercise_id at index $index should be preserved");
                $this->assertEquals($exercise['sets'], $retrievedExercise['sets'],
                    "sets at index $index should be preserved");
                $this->assertEquals($exercise['reps'], $retrievedExercise['reps'],
                    "reps at index $index should be preserved");
                $this->assertEquals($exercise['duration_seconds'], $retrievedExercise['duration_seconds'],
                    "duration_seconds at index $index should be preserved");
                $this->assertEquals($exercise['order'], $retrievedExercise['order'],
                    "order at index $index should be preserved");
            }

            // Clean up for next iteration
            $workout->delete();
        });
    }

    /**
     * Create an Eris generator for arrays of exercise objects.
     *
     * Each exercise object has:
     * - exercise_id: positive integer (1-100)
     * - sets: positive integer (1-20)
     * - reps: positive integer (1-100)
     * - duration_seconds: non-negative integer (0-3600)
     * - order: positive integer (1-20)
     *
     * The array contains 1-10 exercise objects.
     */
    private function exercisesArrayGenerator(): \Eris\Generator
    {
        // Generate an array of 1-10 exercise objects, each with
        // exercise_id, sets, reps, duration_seconds, and order fields
        return Generators::map(
            function (array $tuple): array {
                $count = ($tuple[0] % 10) + 1; // 1 to 10 exercises
                $exercises = [];
                for ($i = 0; $i < $count; $i++) {
                    $exercises[] = [
                        'exercise_id' => (($tuple[1 + $i * 5] % 100) + 1),
                        'sets' => (($tuple[2 + $i * 5] % 20) + 1),
                        'reps' => (($tuple[3 + $i * 5] % 100) + 1),
                        'duration_seconds' => ($tuple[4 + $i * 5] % 3601),
                        'order' => $i + 1,
                    ];
                }
                return $exercises;
            },
            Generators::tuple(
                Generators::choose(0, 9),         // count seed
                // 10 exercises * 5 fields = 50 values needed (max)
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20),
                Generators::choose(1, 100), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600), Generators::choose(1, 20)
            )
        );
    }
}
