<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProfileRequest;
use App\Http\Requests\UpdateProfileRequest;
use Illuminate\Http\JsonResponse;

class ProfileController extends Controller
{
    /**
     * Display the authenticated user's profile.
     */
    public function show(): JsonResponse
    {
        $profile = auth()->user()->profile;

        if (!$profile) {
            return $this->errorResponse('No profile exists', 404);
        }

        return $this->successResponse($profile);
    }

    /**
     * Create the authenticated user's profile.
     */
    public function store(StoreProfileRequest $request): JsonResponse
    {
        $user = auth()->user();

        if ($user->profile) {
            return $this->errorResponse('Profile already exists', 409);
        }

        $data = $request->validated();
        $data['user_id'] = $user->id;
        $data['bmi'] = $this->computeBmi($data['weight_kg'], $data['height_cm']);

        $profile = $user->profile()->create($data);

        return $this->createdResponse($profile);
    }

    /**
     * Update the authenticated user's profile.
     */
    public function update(UpdateProfileRequest $request): JsonResponse
    {
        $profile = auth()->user()->profile;

        if (!$profile) {
            return $this->errorResponse('No profile exists', 404);
        }

        $data = $request->validated();

        // Recompute BMI if height or weight changed
        $heightCm = $data['height_cm'] ?? $profile->height_cm;
        $weightKg = $data['weight_kg'] ?? $profile->weight_kg;

        if (isset($data['height_cm']) || isset($data['weight_kg'])) {
            $data['bmi'] = $this->computeBmi($weightKg, $heightCm);
        }

        $profile->update($data);
        $profile->refresh();

        return $this->successResponse($profile);
    }

    /**
     * Compute BMI: weight_kg / (height_cm / 100)^2, rounded to 2 decimals.
     */
    private function computeBmi(float $weightKg, float $heightCm): float
    {
        return round($weightKg / pow($heightCm / 100, 2), 2);
    }
}
