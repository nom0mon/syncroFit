<?php

namespace App\Http\Controllers;

use App\Models\ProgressRecord;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

class ProgressController extends Controller
{
    /**
     * Get progress summary for the authenticated user.
     *
     * Returns total workouts, current streak, longest streak, and latest weight.
     * Requirements: 10.1, 10.3
     */
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user();

        $records = ProgressRecord::where('user_id', $user->id)
            ->where('workouts_completed', '>', 0)
            ->orderBy('recorded_at', 'asc')
            ->get();

        $totalWorkouts = $records->sum('workouts_completed');

        $latestWeight = ProgressRecord::where('user_id', $user->id)
            ->whereNotNull('weight_kg')
            ->latest('recorded_at')
            ->value('weight_kg');

        $currentStreak = $this->calculateCurrentStreak($records);
        $longestStreak = $this->calculateLongestStreak($records);

        return $this->successResponse([
            'total_workouts' => $totalWorkouts,
            'current_streak' => $currentStreak,
            'longest_streak' => $longestStreak,
            'latest_weight' => $latestWeight ? (float) $latestWeight : null,
        ]);
    }

    /**
     * Get weight/BMI history for the authenticated user.
     *
     * Returns all ProgressRecords ordered by recorded_at ascending.
     * Requirements: 10.2
     */
    public function history(Request $request): JsonResponse
    {
        $user = $request->user();

        $records = ProgressRecord::where('user_id', $user->id)
            ->orderBy('recorded_at', 'asc')
            ->get();

        return $this->successResponse([
            'records' => $records,
        ]);
    }

    /**
     * Get weekly workout stats for the authenticated user.
     *
     * Returns workouts completed per day for the current week (Mon-Sun).
     * Requirements: 10.4
     */
    public function weeklyStats(Request $request): JsonResponse
    {
        $user = $request->user();
        $startOfWeek = Carbon::now()->startOfWeek(); // Monday
        $endOfWeek = Carbon::now()->endOfWeek(); // Sunday

        $records = ProgressRecord::where('user_id', $user->id)
            ->whereBetween('recorded_at', [$startOfWeek->toDateString(), $endOfWeek->toDateString()])
            ->get()
            ->keyBy(function ($record) {
                return Carbon::parse($record->recorded_at)->toDateString();
            });

        $stats = [];
        for ($i = 0; $i < 7; $i++) {
            $date = $startOfWeek->copy()->addDays($i);
            $dateStr = $date->toDateString();
            $stats[] = [
                'date' => $dateStr,
                'day' => $date->format('l'),
                'workouts_completed' => $records->has($dateStr) ? $records[$dateStr]->workouts_completed : 0,
            ];
        }

        return $this->successResponse(['weekly_stats' => $stats]);
    }

    /**
     * Calculate the current streak of consecutive days with workouts.
     *
     * Current streak counts consecutive days (going backwards from today or yesterday)
     * that have workouts_completed > 0.
     */
    private function calculateCurrentStreak(Collection $records): int
    {
        if ($records->isEmpty()) {
            return 0;
        }

        // Get unique dates with workouts
        $dates = $records->pluck('recorded_at')
            ->map(fn ($date) => Carbon::parse($date)->toDateString())
            ->unique()
            ->sort()
            ->values();

        $today = Carbon::today()->toDateString();
        $yesterday = Carbon::yesterday()->toDateString();

        // If neither today nor yesterday has a workout, streak is 0
        if (!$dates->contains($today) && !$dates->contains($yesterday)) {
            return 0;
        }

        // Start counting from today if it has a workout, otherwise from yesterday
        $startDate = $dates->contains($today) ? Carbon::today() : Carbon::yesterday();
        $streak = 0;

        while (true) {
            $checkDate = $startDate->copy()->subDays($streak)->toDateString();
            if ($dates->contains($checkDate)) {
                $streak++;
            } else {
                break;
            }
        }

        return $streak;
    }

    /**
     * Calculate the longest streak of consecutive days with workouts.
     *
     * Finds the maximum run of consecutive dates with workouts_completed > 0.
     */
    private function calculateLongestStreak(Collection $records): int
    {
        if ($records->isEmpty()) {
            return 0;
        }

        // Get unique dates with workouts, sorted
        $dates = $records->pluck('recorded_at')
            ->map(fn ($date) => Carbon::parse($date)->toDateString())
            ->unique()
            ->sort()
            ->values()
            ->toArray();

        if (empty($dates)) {
            return 0;
        }

        $longestStreak = 1;
        $currentStreak = 1;

        for ($i = 1; $i < count($dates); $i++) {
            $prevDate = Carbon::parse($dates[$i - 1]);
            $currDate = Carbon::parse($dates[$i]);

            if ($prevDate->diffInDays($currDate) === 1) {
                $currentStreak++;
                $longestStreak = max($longestStreak, $currentStreak);
            } else {
                $currentStreak = 1;
            }
        }

        return $longestStreak;
    }
}
