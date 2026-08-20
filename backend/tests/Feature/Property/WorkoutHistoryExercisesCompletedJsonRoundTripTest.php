<?php

namespace Tests\Feature\Property;

use App\Models\User;
use App\Models\WorkoutHistory;
use Eris\TestTrait;
use Eris\Generators;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Property Test: WorkoutHistory exercises_completed JSON round-trip (Property 4)
 *
 * Feature: database-simplification
 * Property 4: WorkoutHistory exercises_completed JSON round-trip
 *
 * For any valid array of exercise completion objects, storing the array in a
 * WorkoutHistory model's `exercises_completed` column and reading it back
 * SHALL produce an identical array.
 *
 * **Validates: Requirements 4.2**
 */
class WorkoutHistoryExercisesCompletedJsonRoundTripTest extends TestCase
{
    use TestTrait;
    use RefreshDatabase;

    /**
     * Property 4: WorkoutHistory exercises_completed JSON round-trip
     *
     * Using Eris, generate arrays of exercise completion objects, store in
     * WorkoutHistory model, verify identical on read-back.
     *
     * Each exercise completion object has:
     * - exercise_id (int)
     * - exercise_name (string)
     * - sets_completed (int)
     * - reps_completed (int)
     * - skipped (bool)
     *
     * **Validates: Requirements 4.2**
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_exercises_completed_json_round_trip_property(): void
    {
        $this->limitTo(100);

        $user = User::create([
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'test-pbt-wh@example.com',
            'password' => bcrypt('password'),
        ]);

        $this->forAll(
            $this->exercisesCompletedGenerator()
        )->then(function (array $exercisesCompleted) use ($user): void {
            // Store in WorkoutHistory model
            $workoutHistory = WorkoutHistory::create([
                'user_id' => $user->id,
                'workout_name' => 'Test Workout',
                'completed_at' => now(),
                'total_duration_seconds' => 1800,
                'exercises_completed' => $exercisesCompleted,
            ]);

            // Read back from database
            $retrieved = WorkoutHistory::find($workoutHistory->id);

            // Verify the exercises_completed array is identical
            $this->assertEquals(
                $exercisesCompleted,
                $retrieved->exercises_completed,
                'exercises_completed JSON round-trip failed. '
                . 'Stored: ' . json_encode($exercisesCompleted) . ' '
                . 'Retrieved: ' . json_encode($retrieved->exercises_completed)
            );

            // Clean up for next iteration
            $workoutHistory->delete();
        });
    }

    /**
     * Create a custom Eris generator for arrays of exercise completion objects.
     *
     * Each object has the structure:
     * {
     *   "exercise_id": int (1-1000),
     *   "exercise_name": string,
     *   "sets_completed": int (1-10),
     *   "reps_completed": int (1-50),
     *   "skipped": bool
     * }
     *
     * Generates arrays with 1-8 exercise completion objects.
     */
    private function exercisesCompletedGenerator(): \Eris\Generator
    {
        $exerciseNames = [
            'Push Ups', 'Squats', 'Deadlift', 'Bench Press', 'Barbell Row',
            'Pull Ups', 'Overhead Press', 'Lunges', 'Plank', 'Burpees',
            'Dumbbell Curl', 'Tricep Dip', 'Leg Press', 'Calf Raise',
            'Kettlebell Swing', 'Cable Fly', 'Lat Pulldown', 'Hip Thrust',
            'Mountain Climber', 'Russian Twist',
        ];

        return Generators::bind(
            Generators::choose(1, 8),
            function (int $count) use ($exerciseNames): \Eris\Generator {
                $generators = [];
                for ($i = 0; $i < $count; $i++) {
                    $generators[] = Generators::tuple(
                        Generators::choose(1, 1000),         // exercise_id
                        Generators::elements($exerciseNames), // exercise_name
                        Generators::choose(1, 10),           // sets_completed
                        Generators::choose(1, 50),           // reps_completed
                        Generators::elements([true, false])   // skipped
                    );
                }

                return Generators::map(
                    function (array $tuples): array {
                        return array_map(function (array $tuple): array {
                            return [
                                'exercise_id' => $tuple[0],
                                'exercise_name' => $tuple[1],
                                'sets_completed' => $tuple[2],
                                'reps_completed' => $tuple[3],
                                'skipped' => $tuple[4],
                            ];
                        }, $tuples);
                    },
                    Generators::tuple(...$generators)
                );
            }
        );
    }
}
