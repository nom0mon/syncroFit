<?php

namespace Tests\Feature;

use App\Models\ProgressRecord;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProgressTest extends TestCase
{
    use RefreshDatabase;

    public function test_summary_returns_correct_data(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => now()->toDateString(),
            'weight_kg' => 75.0,
            'bmi' => 24.22,
            'workouts_completed' => 2,
        ]);

        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => now()->subDay()->toDateString(),
            'weight_kg' => 75.5,
            'bmi' => 24.38,
            'workouts_completed' => 1,
        ]);

        $response = $this->getJson('/api/progress/summary');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.total_workouts', 3)
            ->assertJsonPath('data.current_streak', 2)
            ->assertJsonPath('data.longest_streak', 2)
            ->assertJsonPath('data.latest_weight', 75.0); // Today's record is latest
    }

    public function test_summary_returns_zeros_with_no_data(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/progress/summary');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.total_workouts', 0)
            ->assertJsonPath('data.current_streak', 0)
            ->assertJsonPath('data.longest_streak', 0)
            ->assertJsonPath('data.latest_weight', null);
    }

    public function test_summary_current_streak_counts_from_today(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Records for today, yesterday, day before → streak=3
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => Carbon::today()->toDateString(),
            'workouts_completed' => 1,
        ]);
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => Carbon::yesterday()->toDateString(),
            'workouts_completed' => 1,
        ]);
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => Carbon::today()->subDays(2)->toDateString(),
            'workouts_completed' => 1,
        ]);

        $response = $this->getJson('/api/progress/summary');

        $response->assertStatus(200)
            ->assertJsonPath('data.current_streak', 3);
    }

    public function test_summary_current_streak_counts_from_yesterday(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // No record today, but records yesterday and day before → streak=2
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => Carbon::yesterday()->toDateString(),
            'workouts_completed' => 1,
        ]);
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => Carbon::today()->subDays(2)->toDateString(),
            'workouts_completed' => 1,
        ]);

        $response = $this->getJson('/api/progress/summary');

        $response->assertStatus(200)
            ->assertJsonPath('data.current_streak', 2);
    }

    public function test_summary_current_streak_resets_on_gap(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Records for today and 3 days ago (gap in between) → streak=1
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => Carbon::today()->toDateString(),
            'workouts_completed' => 1,
        ]);
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => Carbon::today()->subDays(3)->toDateString(),
            'workouts_completed' => 1,
        ]);

        $response = $this->getJson('/api/progress/summary');

        $response->assertStatus(200)
            ->assertJsonPath('data.current_streak', 1);
    }

    public function test_summary_longest_streak(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Records on days 1-5 (consecutive) and days 10-12 (consecutive) → longest_streak=5
        $baseDate = Carbon::today()->subDays(20);

        for ($i = 1; $i <= 5; $i++) {
            ProgressRecord::create([
                'user_id' => $user->id,
                'recorded_at' => $baseDate->copy()->addDays($i)->toDateString(),
                'workouts_completed' => 1,
            ]);
        }

        for ($i = 10; $i <= 12; $i++) {
            ProgressRecord::create([
                'user_id' => $user->id,
                'recorded_at' => $baseDate->copy()->addDays($i)->toDateString(),
                'workouts_completed' => 1,
            ]);
        }

        $response = $this->getJson('/api/progress/summary');

        $response->assertStatus(200)
            ->assertJsonPath('data.longest_streak', 5);
    }

    public function test_history_returns_records_in_ascending_order(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Create records out of order
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => '2024-03-15',
            'weight_kg' => 73.0,
            'bmi' => 23.57,
            'workouts_completed' => 1,
        ]);
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => '2024-03-10',
            'weight_kg' => 74.0,
            'bmi' => 23.90,
            'workouts_completed' => 2,
        ]);
        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => '2024-03-20',
            'weight_kg' => 72.5,
            'bmi' => 23.41,
            'workouts_completed' => 1,
        ]);

        $response = $this->getJson('/api/progress/history');

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $records = $response->json('data.records');
        $this->assertCount(3, $records);

        // Verify ascending order by recorded_at
        $this->assertEquals('2024-03-10', Carbon::parse($records[0]['recorded_at'])->toDateString());
        $this->assertEquals('2024-03-15', Carbon::parse($records[1]['recorded_at'])->toDateString());
        $this->assertEquals('2024-03-20', Carbon::parse($records[2]['recorded_at'])->toDateString());
    }

    public function test_weekly_stats_returns_all_7_days(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/progress/weekly-stats');

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $stats = $response->json('data.weekly_stats');
        $this->assertCount(7, $stats);

        // Verify it starts with Monday and ends with Sunday
        $this->assertEquals('Monday', $stats[0]['day']);
        $this->assertEquals('Tuesday', $stats[1]['day']);
        $this->assertEquals('Wednesday', $stats[2]['day']);
        $this->assertEquals('Thursday', $stats[3]['day']);
        $this->assertEquals('Friday', $stats[4]['day']);
        $this->assertEquals('Saturday', $stats[5]['day']);
        $this->assertEquals('Sunday', $stats[6]['day']);
    }

    public function test_weekly_stats_shows_correct_counts(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Create records for specific days this week
        $monday = Carbon::now()->startOfWeek(); // Monday

        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => $monday->toDateString(),
            'workouts_completed' => 2,
        ]);

        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => $monday->copy()->addDays(2)->toDateString(), // Wednesday
            'workouts_completed' => 3,
        ]);

        $response = $this->getJson('/api/progress/weekly-stats');

        $response->assertStatus(200);

        $stats = $response->json('data.weekly_stats');

        // Monday has 2 workouts
        $this->assertEquals(2, $stats[0]['workouts_completed']);
        // Wednesday has 3 workouts
        $this->assertEquals(3, $stats[2]['workouts_completed']);
    }

    public function test_weekly_stats_returns_zeros_for_empty_days(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Create only one record this week
        $monday = Carbon::now()->startOfWeek();

        ProgressRecord::create([
            'user_id' => $user->id,
            'recorded_at' => $monday->toDateString(),
            'workouts_completed' => 1,
        ]);

        $response = $this->getJson('/api/progress/weekly-stats');

        $response->assertStatus(200);

        $stats = $response->json('data.weekly_stats');

        // Monday has 1 workout
        $this->assertEquals(1, $stats[0]['workouts_completed']);

        // All other days should be 0
        for ($i = 1; $i < 7; $i++) {
            $this->assertEquals(0, $stats[$i]['workouts_completed'], "Day index {$i} should have 0 workouts");
        }
    }

    public function test_unauthenticated_request_returns_401(): void
    {
        // Summary without auth
        $response = $this->getJson('/api/progress/summary');
        $response->assertStatus(401);

        // History without auth
        $response = $this->getJson('/api/progress/history');
        $response->assertStatus(401);

        // Weekly stats without auth
        $response = $this->getJson('/api/progress/weekly-stats');
        $response->assertStatus(401);
    }
}
