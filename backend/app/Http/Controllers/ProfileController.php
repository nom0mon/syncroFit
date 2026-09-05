<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProfileRequest;
use App\Http\Requests\UpdateProfileRequest;
use App\Models\Exercise;
use App\Models\Workout;
use App\Services\WorkoutPrescriptionPolicy;
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

        return $this->successResponse($this->profileWithName($profile));
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

        return $this->createdResponse($this->profileWithName($profile));
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

        if (array_key_exists('fitness_level', $data) || array_key_exists('goal', $data)) {
            $policy = app(WorkoutPrescriptionPolicy::class);
            Workout::where('user_id', $profile->user_id)
                ->where('is_generated', true)
                ->each(function (Workout $workout) use ($profile, $policy): void {
                    $ids = collect($workout->exercises)->pluck('exercise_id')->map(fn ($id) => (int) $id)->all();
                    $models = Exercise::whereIn('id', $ids)->get()->keyBy('id');
                    $normalized = [];
                    foreach ($ids as $index => $id) {
                        if ($models->has($id)) {
                            $normalized[] = $policy->prescribe($models[$id], $profile->fitness_level, $profile->goal, $index + 1);
                        }
                    }
                    if ($normalized !== []) {
                        $workout->update([
                            'exercises' => $normalized,
                            'estimated_duration_minutes' => $policy->estimatedDurationMinutes($normalized),
                        ]);
                    }
                });
        }

        return $this->successResponse($this->profileWithName($profile));
    }

    /**
     * Appends the authenticated user's name fields to the profile data.
     */
    private function profileWithName($profile): array
    {
        $data = $profile->toArray();
        $user = auth()->user();
        $data['first_name'] = $user->first_name;
        $data['last_name'] = $user->last_name;
        $data['name'] = $user->full_name; // backward compat
        return $data;
    }

    /**
     * Compute BMI: weight_kg / (height_cm / 100)^2, rounded to 2 decimals.
     */
    private function computeBmi(float $weightKg, float $heightCm): float
    {
        return round($weightKg / pow($heightCm / 100, 2), 2);
    }
}
