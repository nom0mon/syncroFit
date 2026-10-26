<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use App\Models\User;
use App\Models\Workout;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Workout exercises round-trip (3NF normalization).
 *
 * The former `workouts.exercises` JSON column is now the `workout_exercises`
 * relation, exposed via the model's virtual `exercises` attribute. This test
 * verifies that assigning an exercises array and reading it back preserves the
 * data exactly, across a range of shapes. exercise_id references real catalog
 * rows (FK-enforced).
 *
 * Replaces the former Eris JSON-column round-trip (the arbitrary-JSON contract
 * no longer exists under the normalized schema).
 *
 * **Validates: Requirements 3.2**
 */
class WorkoutExercisesJsonRoundTripTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    /** @var array<int, int> */
    private array $exerciseIds = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::create([
            'first_name' => 'Test',
            'last_name' => 'User',
            'email' => 'testuser_' . uniqid() . '@example.com',
            'password' => bcrypt('password'),
        ]);
        $this->exerciseIds = Exercise::factory()->count(10)->create()->pluck('id')->all();
    }

    /**
     * @return iterable<string, array{int, int, int, int}>
     */
    public static function exerciseShapes(): iterable
    {
        // [count, setsBase, repsBase, durationBase]
        yield 'single rep-based' => [1, 3, 10, 0];
        yield 'single timed' => [1, 4, 1, 45];
        yield 'two exercises' => [2, 3, 12, 0];
        yield 'five exercises' => [5, 4, 8, 30];
        yield 'ten exercises (max)' => [10, 5, 15, 60];
        yield 'mixed volumes' => [7, 2, 20, 0];
    }

    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    #[\PHPUnit\Framework\Attributes\DataProvider('exerciseShapes')]
    public function test_workout_exercises_round_trip(
        int $count,
        int $setsBase,
        int $repsBase,
        int $durationBase
    ): void {
        $exercises = [];
        for ($i = 0; $i < $count; $i++) {
            $exercises[] = [
                'exercise_id' => $this->exerciseIds[$i % count($this->exerciseIds)],
                'sets' => (($setsBase + $i) % 20) + 1,
                'reps' => (($repsBase + $i) % 100) + 1,
                'duration_seconds' => ($durationBase + $i * 5) % 3601,
                'rest_seconds' => ($i * 15) % 180,
                'order' => $i + 1,
            ];
        }

        $workout = Workout::create([
            'user_id' => $this->user->id,
            'name' => 'Test Workout',
            'day_of_week' => 'Monday',
            'estimated_duration_minutes' => 30,
            'exercises' => $exercises,
            'is_generated' => false,
        ]);

        $retrieved = Workout::find($workout->id);

        $this->assertNotNull($retrieved);
        $this->assertEquals(
            $exercises,
            $retrieved->exercises,
            'Exercises should be identical after relation round-trip. '
            . 'Stored: ' . json_encode($exercises) . ' Retrieved: ' . json_encode($retrieved->exercises)
        );
        $this->assertCount($count, $retrieved->exercises);
    }

    /**
     * Updating the virtual attribute replaces the related rows (no leftovers).
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_updating_exercises_replaces_relation_rows(): void
    {
        $workout = Workout::create([
            'user_id' => $this->user->id,
            'name' => 'Test Workout',
            'exercises' => [
                ['exercise_id' => $this->exerciseIds[0], 'sets' => 3, 'reps' => 10, 'duration_seconds' => 0, 'order' => 1],
                ['exercise_id' => $this->exerciseIds[1], 'sets' => 3, 'reps' => 12, 'duration_seconds' => 0, 'order' => 2],
            ],
            'is_generated' => false,
        ]);

        $workout->update([
            'exercises' => [
                ['exercise_id' => $this->exerciseIds[2], 'sets' => 4, 'reps' => 8, 'duration_seconds' => 0, 'order' => 1],
            ],
        ]);

        $this->assertDatabaseCount('workout_exercises', 1);
        $this->assertEquals($this->exerciseIds[2], Workout::find($workout->id)->exercises[0]['exercise_id']);
    }
}
