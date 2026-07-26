<?php

namespace App\Http\Controllers;

use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    /**
     * Store/replace a device token for the authenticated user.
     *
     * POST /api/device-tokens
     * Body: { "token": "<FCM token>", "device_id": "<device identifier>" }
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'token' => 'required|string',
            'device_id' => 'required|string',
        ]);

        $user = $request->user();

        $deviceToken = DeviceToken::updateOrCreate(
            ['user_id' => $user->id, 'device_id' => $request->input('device_id')],
            ['token' => $request->input('token')]
        );

        return $this->successResponse($deviceToken, 'Device token registered successfully.');
    }
}
