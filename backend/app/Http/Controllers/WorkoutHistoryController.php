<?php

namespace App\Http\Controllers;

use App\Models\WorkoutHistory;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WorkoutHistoryController extends Controller
{
    /**
     * Record a completed workout session.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'workout_name' => 'required|string|max:255',
            'completed_at' => 'required|date',
            'total_duration_seconds' => 'required|integer|min:0',
            'exercises_completed' => 'required|array',
        ]);

        $record = WorkoutHistory::create([
            'user_id' => $request->user()->id,
            'workout_name' => $validated['workout_name'],
            'completed_at' => $validated['completed_at'],
            'total_duration_seconds' => $validated['total_duration_seconds'],
            'exercises_completed' => $validated['exercises_completed'],
        ]);

        return response()->json(['success' => true, 'data' => $record], 201);
    }

    /**
     * List workout history for the authenticated user.
     */
    public function index(Request $request): JsonResponse
    {
        $history = WorkoutHistory::where('user_id', $request->user()->id)
            ->orderBy('completed_at', 'desc')
            ->get();

        return response()->json(['success' => true, 'data' => $history]);
    }

    /**
     * Compute progress statistics from workout history.
     *
     * Returns:
     * - total_workouts: count of workout_history records
     * - total_duration: sum of all total_duration_seconds values
     * - weekly_stats: records grouped by ISO week (year-week format)
     */
    public function stats(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $history = WorkoutHistory::where('user_id', $userId)->get();

        $totalWorkouts = $history->count();
        $totalDuration = $history->sum('total_duration_seconds');

        // Group by ISO week (year-week format)
        $weeklyStats = $history->groupBy(function ($record) {
            $date = Carbon::parse($record->completed_at);
            return $date->isoFormat('GGGG-[W]WW');
        })->map(function ($weekRecords, $weekKey) {
            return [
                'week' => $weekKey,
                'workouts' => $weekRecords->count(),
                'total_duration' => $weekRecords->sum('total_duration_seconds'),
            ];
        })->values()->toArray();

        return response()->json([
            'success' => true,
            'data' => [
                'total_workouts' => $totalWorkouts,
                'total_duration' => $totalDuration,
                'weekly_stats' => $weeklyStats,
            ],
        ]);
    }
}
