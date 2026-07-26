<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RecommendationController extends Controller
{
    /**
     * Generate a weekly workout plan.
     * Placeholder — full implementation in Task 6.3.
     */
    public function generate(Request $request): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }

    /**
     * Get the current recommendation.
     * Placeholder — full implementation in Task 6.3.
     */
    public function current(Request $request): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }
}
