<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProgressController extends Controller
{
    /**
     * Get progress summary for the authenticated user.
     * Placeholder — full implementation in Task 8.1.
     */
    public function summary(Request $request): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }

    /**
     * Get weight/BMI history for the authenticated user.
     * Placeholder — full implementation in Task 8.1.
     */
    public function history(Request $request): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }

    /**
     * Get weekly workout stats for the authenticated user.
     * Placeholder — full implementation in Task 8.1.
     */
    public function weeklyStats(Request $request): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }
}
