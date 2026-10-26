<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use App\Models\User;
use App\Models\WorkoutHistory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * WorkoutHistory exercises_completed round-trip (3NF normalization).
 *
 * The former `workout_history.exercises_completed` JSON column is now the
 * `workout_history_exercises` relation, exposed via the model's virtual
 * `exercises_completed` attribute. This test verifies the data round-trips
 * through that relation. exercise_id references real catalog rows.
 *
 * Replaces the former Eris JSON-column round-trip (the arbitrary-JSON contract
 * no longer exists under the normalized schema).
 *
 * **Validates: Requirements 4.2**
 */
class WorkoutHistoryExercisesCompletedJsonRoundTripTest extends TestCase
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
            'email' => 'test-pbt-wh@example.com',
            'password' => bcrypt('password'),
        ]);
        $this->exerciseIds = Exercise::factory()->count(10)->create()->pluck('id')->all();
    }

    /**
     * @return iterable<string, array{int}>
     */
    public static function completionCounts(): iterable
    {
        yield 'one exercise' => [1];
        yield 'two exercises' => [2];
        yield 'four exercises' => [4];
        yield 'eight exercises' => [8];
    }

    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    #[\PHPUnit\Framework\Attributes\DataProvider('completionCounts')]
    public function test_exercises_completed_round_trip(int $count): void
    {
        $names = ['Push Ups', 'Squats', 'Deadlift', 'Bench Press', 'Barbell Row',
            'Pull Ups', 'Overhead Press', 'Lunges'];

        $completed = [];
        for ($i = 0; $i < $count; $i++) {
            $completed[] = [
                'exercise_id' => (string) $this->exerciseIds[$i % count($this->exerciseIds)],
                'exercise_name' => $names[$i % count($names)],
                'sets_completed' => ($i % 10) + 1,
                'reps_or_duration' => (($i * 7) % 50) + 1,
                'is_duration' => ($i % 2 === 0),
            ];
        }

        $history = WorkoutHistory::create([
            'user_id' => $this->user->id,
            'workout_name' => 'Test Workout',
            'completed_at' => now(),
            'total_duration_seconds' => 1800,
            'exercises_completed' => $completed,
        ]);

        $retrieved = WorkoutHistory::find($history->id);

        $this->assertEquals(
            $completed,
            $retrieved->exercises_completed,
            'exercises_completed should round-trip through the relation. '
            . 'Stored: ' . json_encode($completed) . ' '
            . 'Retrieved: ' . json_encode($retrieved->exercises_completed)
        );
    }

    /**
     * A completed session with zero exercises is valid and round-trips as [].
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_empty_completion_round_trips(): void
    {
        $history = WorkoutHistory::create([
            'user_id' => $this->user->id,
            'workout_name' => 'Skipped everything',
            'completed_at' => now(),
            'total_duration_seconds' => 60,
            'exercises_completed' => [],
        ]);

        $this->assertSame([], WorkoutHistory::find($history->id)->exercises_completed);
        $this->assertDatabaseCount('workout_history_exercises', 0);
    }

    /**
     * The snapshot name survives even if the referenced exercise is deleted;
     * the exercise_id link is nulled (nullOnDelete FK).
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_snapshot_name_survives_exercise_deletion(): void
    {
        $id = $this->exerciseIds[0];
        $history = WorkoutHistory::create([
            'user_id' => $this->user->id,
            'workout_name' => 'Legacy',
            'completed_at' => now(),
            'total_duration_seconds' => 300,
            'exercises_completed' => [[
                'exercise_id' => (string) $id,
                'exercise_name' => 'Bench Press',
                'sets_completed' => 3,
                'reps_or_duration' => 10,
                'is_duration' => false,
            ]],
        ]);

        Exercise::whereKey($id)->delete();

        $retrieved = WorkoutHistory::find($history->id)->exercises_completed;
        $this->assertCount(1, $retrieved);
        $this->assertSame('Bench Press', $retrieved[0]['exercise_name']);
        $this->assertSame('', $retrieved[0]['exercise_id']); // link nulled
    }
}
