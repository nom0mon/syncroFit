<?php

namespace App\Http\Controllers;

use App\Models\ProgressRecord;
use App\Models\SessionExercise;
use App\Models\WorkoutSession;
use App\Models\WorkoutExercise;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WorkoutSessionController extends Controller
{
    /**
     * Start a new workout session.
     * POST /api/sessions
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'workout_id' => 'required|integer|exists:workouts,id',
        ]);

        $user = $request->user();

        // Check if user already has an active session (started or paused)
        $activeSession = WorkoutSession::where('user_id', $user->id)
            ->whereIn('status', ['started', 'paused'])
            ->first();

        if ($activeSession) {
            return $this->errorResponse('An active workout session already exists', 409);
        }

        // Create the session
        $session = WorkoutSession::create([
            'user_id' => $user->id,
            'workout_id' => $request->input('workout_id'),
            'status' => 'started',
            'started_at' => Carbon::now(),
            'pause_log' => [],
        ]);

        // Create SessionExercise records for each WorkoutExercise in the workout
        $workoutExercises = WorkoutExercise::where('workout_id', $request->input('workout_id'))
            ->orderBy('order')
            ->get();

        foreach ($workoutExercises as $workoutExercise) {
            SessionExercise::create([
                'workout_session_id' => $session->id,
                'exercise_id' => $workoutExercise->exercise_id,
                'status' => 'pending',
                'sets_completed' => 0,
                'reps_completed' => 0,
            ]);
        }

        $session->load('sessionExercises');

        return $this->createdResponse($session->toArray(), 'Workout session started');
    }

    /**
     * Pause an active workout session.
     * PATCH /api/sessions/{session}/pause
     */
    public function pause(Request $request, $session): JsonResponse
    {
        $workoutSession = $this->findUserSession($request, $session);

        if ($workoutSession instanceof JsonResponse) {
            return $workoutSession;
        }

        // Only valid if current status = 'started'
        if ($workoutSession->status !== 'started') {
            return $this->errorResponse(
                "Cannot pause session. Current state: {$workoutSession->status}",
                422
            );
        }

        // Append pause entry to pause_log
        $pauseLog = $workoutSession->pause_log ?? [];
        $pauseLog[] = ['paused_at' => Carbon::now()->toIso8601String()];

        $workoutSession->update([
            'status' => 'paused',
            'pause_log' => $pauseLog,
        ]);

        $workoutSession->load('sessionExercises');

        return $this->successResponse($workoutSession->toArray(), 'Session paused');
    }

    /**
     * Resume a paused workout session.
     * PATCH /api/sessions/{session}/resume
     */
    public function resume(Request $request, $session): JsonResponse
    {
        $workoutSession = $this->findUserSession($request, $session);

        if ($workoutSession instanceof JsonResponse) {
            return $workoutSession;
        }

        // Only valid if current status = 'paused'
        if ($workoutSession->status !== 'paused') {
            return $this->errorResponse(
                "Cannot resume session. Current state: {$workoutSession->status}",
                422
            );
        }

        // Set resumed_at on the last pause entry
        $pauseLog = $workoutSession->pause_log ?? [];
        if (!empty($pauseLog)) {
            $lastIndex = count($pauseLog) - 1;
            $pauseLog[$lastIndex]['resumed_at'] = Carbon::now()->toIso8601String();
        }

        $workoutSession->update([
            'status' => 'started',
            'pause_log' => $pauseLog,
        ]);

        $workoutSession->load('sessionExercises');

        return $this->successResponse($workoutSession->toArray(), 'Session resumed');
    }

    /**
     * Skip an exercise in a workout session.
     * PATCH /api/sessions/{session}/skip-exercise
     */
    public function skipExercise(Request $request, $session): JsonResponse
    {
        $request->validate([
            'exercise_id' => 'required|integer',
        ]);

        $workoutSession = $this->findUserSession($request, $session);

        if ($workoutSession instanceof JsonResponse) {
            return $workoutSession;
        }

        // Cannot modify completed session
        if ($workoutSession->status === 'completed') {
            return $this->errorResponse('Cannot modify completed session', 422);
        }

        // Find the SessionExercise for this session + exercise_id
        $sessionExercise = SessionExercise::where('workout_session_id', $workoutSession->id)
            ->where('exercise_id', $request->input('exercise_id'))
            ->first();

        if (!$sessionExercise) {
            return $this->errorResponse('Exercise not found in this session', 404);
        }

        $sessionExercise->update(['status' => 'skipped']);

        $workoutSession->load('sessionExercises');

        return $this->successResponse($workoutSession->toArray(), 'Exercise skipped');
    }

    /**
     * Complete a workout session.
     * PATCH /api/sessions/{session}/complete
     */
    public function complete(Request $request, $session): JsonResponse
    {
        $workoutSession = $this->findUserSession($request, $session);

        if ($workoutSession instanceof JsonResponse) {
            return $workoutSession;
        }

        // Only valid if current status is 'started' or 'paused'
        if ($workoutSession->status === 'completed') {
            return $this->errorResponse('Session is already completed', 422);
        }

        if (!in_array($workoutSession->status, ['started', 'paused'])) {
            return $this->errorResponse(
                "Cannot complete session. Current state: {$workoutSession->status}",
                422
            );
        }

        $now = Carbon::now();
        $pauseLog = $workoutSession->pause_log ?? [];

        // If currently paused, close the last pause entry
        if ($workoutSession->status === 'paused' && !empty($pauseLog)) {
            $lastIndex = count($pauseLog) - 1;
            if (!isset($pauseLog[$lastIndex]['resumed_at'])) {
                $pauseLog[$lastIndex]['resumed_at'] = $now->toIso8601String();
            }
        }

        // Calculate total_duration_seconds
        $startedAt = Carbon::parse($workoutSession->started_at);
        $elapsed = $now->diffInSeconds($startedAt);

        // Calculate total paused time
        $pausedTime = 0;
        foreach ($pauseLog as $entry) {
            $pausedAt = Carbon::parse($entry['paused_at']);
            $resumedAt = isset($entry['resumed_at']) ? Carbon::parse($entry['resumed_at']) : $now;
            $pausedTime += $resumedAt->diffInSeconds($pausedAt);
        }

        $totalDuration = $elapsed - $pausedTime;

        // Mark remaining 'pending' session_exercises as 'completed'
        SessionExercise::where('workout_session_id', $workoutSession->id)
            ->where('status', 'pending')
            ->update(['status' => 'completed']);

        // Update session
        $workoutSession->update([
            'status' => 'completed',
            'completed_at' => $now,
            'total_duration_seconds' => max(0, $totalDuration),
            'pause_log' => $pauseLog,
        ]);

        // Create or update ProgressRecord for today
        $user = $request->user();
        $today = Carbon::now()->toDateString();
        $progressRecord = ProgressRecord::firstOrCreate(
            ['user_id' => $user->id, 'recorded_at' => $today],
            ['weight_kg' => null, 'bmi' => null, 'workouts_completed' => 0]
        );
        $progressRecord->increment('workouts_completed');

        $workoutSession->load('sessionExercises');

        return $this->successResponse($workoutSession->toArray(), 'Session completed');
    }

    /**
     * Find a workout session that belongs to the authenticated user.
     * Returns the session model or a 404 JsonResponse.
     */
    private function findUserSession(Request $request, $sessionId): WorkoutSession|JsonResponse
    {
        $user = $request->user();

        $session = WorkoutSession::where('id', $sessionId)
            ->where('user_id', $user->id)
            ->first();

        if (!$session) {
            return $this->errorResponse('Session not found', 404);
        }

        return $session;
    }
}
