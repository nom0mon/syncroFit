<?php

namespace Tests\Feature\Property;

use App\Models\User;
use App\Models\WorkoutHistory;
use Carbon\Carbon;
use Eris\Generators;
use Eris\TestTrait;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Property Test: Progress statistics computation correctness (Property 5)
 *
 * Feature: database-simplification
 * Property 5: Progress statistics computation correctness
 *
 * For any set of workout_history records belonging to a user, the computed
 * progress statistics SHALL satisfy:
 * - total_workouts equals the count of records
 * - total_duration equals the sum of all total_duration_seconds values
 * - weekly_stats groups records correctly by ISO week
 *
 * **Validates: Requirements 5.7**
 */
class ProgressStatsComputationTest extends TestCase
{
    use TestTrait;
    use RefreshDatabase;

    /**
     * Property 5: Progress statistics computation correctness
     *
     * Using Eris, generate sets of workout_history records and verify:
     * - total_workouts = count of records
     * - total_duration = sum of all total_duration_seconds
     * - weekly grouping is correct by ISO week
     *
     * **Validates: Requirements 5.7**
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_progress_stats_computation_correctness_property(): void
    {
        $this->limitTo(100);

        $user = User::create([
            'first_name' => 'Stats',
            'last_name' => 'Test',
            'email' => 'stats-pbt@example.com',
            'password' => bcrypt('password'),
        ]);

        Sanctum::actingAs($user);

        $this->forAll(
            $this->workoutHistoryRecordsGenerator()
        )->then(function (array $records) use ($user): void {
            // Clean up previous iteration's records
            WorkoutHistory::where('user_id', $user->id)->delete();

            // Insert the generated records
            foreach ($records as $record) {
                WorkoutHistory::create([
                    'user_id' => $user->id,
                    'workout_name' => $record['workout_name'],
                    'completed_at' => $record['completed_at'],
                    'total_duration_seconds' => $record['total_duration_seconds'],
                    'exercises_completed' => $record['exercises_completed'],
                ]);
            }

            // Call the stats endpoint
            $response = $this->getJson('/api/workout-history/stats');
            $response->assertStatus(200);

            $data = $response->json('data');

            // Property assertion 1: total_workouts equals count of records
            $expectedCount = count($records);
            $this->assertEquals(
                $expectedCount,
                $data['total_workouts'],
                "total_workouts should equal count of records. "
                . "Expected: $expectedCount, Got: {$data['total_workouts']}"
            );

            // Property assertion 2: total_duration equals sum of total_duration_seconds
            $expectedDuration = array_sum(array_column($records, 'total_duration_seconds'));
            $this->assertEquals(
                $expectedDuration,
                $data['total_duration'],
                "total_duration should equal sum of total_duration_seconds. "
                . "Expected: $expectedDuration, Got: {$data['total_duration']}"
            );

            // Property assertion 3: weekly_stats groups records correctly by ISO week
            $expectedWeekly = [];
            foreach ($records as $record) {
                $date = Carbon::parse($record['completed_at']);
                $weekKey = $date->isoFormat('GGGG-[W]WW');
                if (!isset($expectedWeekly[$weekKey])) {
                    $expectedWeekly[$weekKey] = [
                        'week' => $weekKey,
                        'workouts' => 0,
                        'total_duration' => 0,
                    ];
                }
                $expectedWeekly[$weekKey]['workouts']++;
                $expectedWeekly[$weekKey]['total_duration'] += $record['total_duration_seconds'];
            }

            $weeklyStats = $data['weekly_stats'];

            // Verify the number of week groups matches
            $this->assertCount(
                count($expectedWeekly),
                $weeklyStats,
                "weekly_stats should have " . count($expectedWeekly) . " groups, "
                . "got " . count($weeklyStats)
            );

            // Verify each weekly group has correct workouts count and duration
            $weeklyStatsByKey = [];
            foreach ($weeklyStats as $stat) {
                $weeklyStatsByKey[$stat['week']] = $stat;
            }

            foreach ($expectedWeekly as $weekKey => $expected) {
                $this->assertArrayHasKey(
                    $weekKey,
                    $weeklyStatsByKey,
                    "weekly_stats should contain week: $weekKey"
                );

                $actual = $weeklyStatsByKey[$weekKey];

                $this->assertEquals(
                    $expected['workouts'],
                    $actual['workouts'],
                    "Week $weekKey: workouts count mismatch. "
                    . "Expected: {$expected['workouts']}, Got: {$actual['workouts']}"
                );

                $this->assertEquals(
                    $expected['total_duration'],
                    $actual['total_duration'],
                    "Week $weekKey: total_duration mismatch. "
                    . "Expected: {$expected['total_duration']}, Got: {$actual['total_duration']}"
                );
            }
        });
    }

    /**
     * Create a custom Eris generator for sets of workout_history records.
     *
     * Generates arrays of 0-10 records, each with:
     * - workout_name: random string from a predefined list
     * - completed_at: random datetime within the last 90 days
     * - total_duration_seconds: random int between 300 and 7200
     * - exercises_completed: simple array with 1-3 exercises
     */
    private function workoutHistoryRecordsGenerator(): \Eris\Generator
    {
        $workoutNames = [
            'Morning Cardio', 'Upper Body', 'Lower Body', 'Full Body',
            'HIIT Session', 'Yoga Flow', 'Chest Day', 'Back Day',
            'Leg Day', 'Core Workout', 'Arms Day', 'Push Day',
            'Pull Day', 'Recovery', 'Sprint Training',
        ];

        return Generators::bind(
            Generators::choose(0, 10),
            function (int $count) use ($workoutNames): \Eris\Generator {
                if ($count === 0) {
                    return Generators::constant([]);
                }

                $generators = [];
                for ($i = 0; $i < $count; $i++) {
                    $generators[] = Generators::tuple(
                        Generators::elements($workoutNames),       // workout_name
                        Generators::choose(1, 90),                 // days ago for completed_at
                        Generators::choose(300, 7200),             // total_duration_seconds
                        Generators::choose(1, 3)                   // num exercises completed
                    );
                }

                return Generators::map(
                    function (array $tuples): array {
                        return array_map(function (array $tuple): array {
                            $daysAgo = $tuple[1];
                            $completedAt = Carbon::now()
                                ->subDays($daysAgo)
                                ->setHour(mt_rand(6, 22))
                                ->setMinute(mt_rand(0, 59))
                                ->setSecond(0);

                            $numExercises = $tuple[3];
                            $exercises = [];
                            for ($e = 0; $e < $numExercises; $e++) {
                                $exercises[] = [
                                    'exercise_id' => mt_rand(1, 50),
                                    'exercise_name' => 'Exercise ' . ($e + 1),
                                    'sets_completed' => mt_rand(2, 5),
                                    'reps_completed' => mt_rand(8, 15),
                                    'skipped' => false,
                                ];
                            }

                            return [
                                'workout_name' => $tuple[0],
                                'completed_at' => $completedAt->toIso8601String(),
                                'total_duration_seconds' => $tuple[2],
                                'exercises_completed' => $exercises,
                            ];
                        }, $tuples);
                    },
                    Generators::tuple(...$generators)
                );
            }
        );
    }
}
