<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    /**
     * Store/replace a device token for the authenticated user.
     * Placeholder — full implementation in Task 14.1.
     */
    public function store(Request $request): JsonResponse
    {
        return $this->errorResponse('Not implemented', 501);
    }
}
