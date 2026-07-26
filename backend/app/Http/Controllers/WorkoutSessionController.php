<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WorkoutSessionController extends Controller
{
    /**
     * Start a new workout session.
     * Placeholder — full implementation in Task 7.1.
     */
    public function store(Request $request): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }

    /**
     * Pause an active workout session.
     * Placeholder — full implementation in Task 7.1.
     */
    public function pause(Request $request, $session): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }

    /**
     * Resume a paused workout session.
     * Placeholder — full implementation in Task 7.1.
     */
    public function resume(Request $request, $session): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }

    /**
     * Skip an exercise in an active session.
     * Placeholder — full implementation in Task 7.1.
     */
    public function skipExercise(Request $request, $session): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }

    /**
     * Complete a workout session.
     * Placeholder — full implementation in Task 7.1.
     */
    public function complete(Request $request, $session): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }
}
