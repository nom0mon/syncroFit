<?php

namespace Tests\Feature\Property;

use App\Models\ProgressRecord;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Property Test: Streak Calculation Correctness (Property 17)
 *
 * Generate random sets of completion dates, verify current_streak equals
 * consecutive days ending today/yesterday, longest_streak equals max consecutive run.
 *
 * **Validates: Requirements 10.1**
 */
class StreakCalculationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Property 17: Streak Calculation Correctness
     *
     * Generate random sets of completion dates, verify current_streak equals
     * consecutive days ending today/yesterday, longest_streak equals max consecutive run.
     *
     * **Validates: Requirements 10.1**
     */
    public function test_streak_calculation_correctness_property(): void
    {
        for ($i = 0; $i < 100; $i++) {
            $user = User::factory()->create();
            Sanctum::actingAs($user);

            // Generate random dates within the past 30 days
            $numDates = mt_rand(0, 15);
            $dates = [];
            for ($d = 0; $d < $numDates; $d++) {
                $daysAgo = mt_rand(0, 30);
                $dates[] = Carbon::today()->subDays($daysAgo)->toDateString();
            }
            $dates = array_unique($dates); // Remove duplicates

            // Create ProgressRecords for each date
            foreach ($dates as $date) {
                ProgressRecord::create([
                    'user_id' => $user->id,
                    'recorded_at' => $date,
                    'workouts_completed' => mt_rand(1, 5),
                ]);
            }

            // Call the API
            $response = $this->getJson('/api/progress/summary');
            $response->assertStatus(200);

            // Calculate expected streaks locally
            $expectedCurrentStreak = $this->calculateExpectedCurrentStreak($dates);
            $expectedLongestStreak = $this->calculateExpectedLongestStreak($dates);

            // Assert
            $this->assertEquals($expectedCurrentStreak, $response->json('data.current_streak'),
                "Iteration $i: Current streak mismatch. Dates: " . implode(', ', $dates));
            $this->assertEquals($expectedLongestStreak, $response->json('data.longest_streak'),
                "Iteration $i: Longest streak mismatch. Dates: " . implode(', ', $dates));
        }
    }

    /**
     * Calculate expected current streak from a set of dates.
     *
     * Current streak is the number of consecutive days ending at today or yesterday.
     */
    private function calculateExpectedCurrentStreak(array $dates): int
    {
        if (empty($dates)) {
            return 0;
        }

        sort($dates);
        $today = Carbon::today()->toDateString();
        $yesterday = Carbon::yesterday()->toDateString();

        if (!in_array($today, $dates) && !in_array($yesterday, $dates)) {
            return 0;
        }

        $startDate = in_array($today, $dates) ? Carbon::today() : Carbon::yesterday();
        $streak = 0;

        while (in_array($startDate->copy()->subDays($streak)->toDateString(), $dates)) {
            $streak++;
        }

        return $streak;
    }

    /**
     * Calculate expected longest streak from a set of dates.
     *
     * Longest streak is the maximum run of consecutive dates.
     */
    private function calculateExpectedLongestStreak(array $dates): int
    {
        if (empty($dates)) {
            return 0;
        }

        sort($dates);
        $maxStreak = 1;
        $currentStreak = 1;

        for ($i = 1; $i < count($dates); $i++) {
            $diff = Carbon::parse($dates[$i - 1])->diffInDays(Carbon::parse($dates[$i]));
            if ($diff === 1) {
                $currentStreak++;
                $maxStreak = max($maxStreak, $currentStreak);
            } elseif ($diff > 1) {
                $currentStreak = 1;
            }
            // if diff === 0, skip (duplicate dates handled by array_unique above)
        }

        return $maxStreak;
    }
}
