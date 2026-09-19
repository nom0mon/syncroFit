<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreProfileRequest;
use App\Http\Requests\UpdateProfileRequest;
use App\Models\Exercise;
use App\Models\Workout;
use App\Services\WorkoutPrescriptionPolicy;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;

class ProfileController extends Controller
{
    public function updateAvatar(\Illuminate\Http\Request $request): JsonResponse
    {
        $validated = $request->validate([
            'avatar' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120', 'dimensions:max_width=4096,max_height=4096'],
        ]);
        $user = $request->user();
        $disk = (string) config('filesystems.community_media_disk', 'public');
        $file = $validated['avatar'];
        $path = $file->store("avatars/{$user->id}", $disk);

        if ($user->avatar_path) {
            Storage::disk($user->avatar_disk ?: $disk)->delete($user->avatar_path);
        }
        $user->forceFill([
            'avatar_disk' => $disk,
            'avatar_path' => $path,
            'avatar_mime_type' => $file->getMimeType(),
        ])->save();

        return $this->successResponse($user->fresh());
    }

    public function avatar(\App\Models\User $user): Response
    {
        abort_if(!$user->avatar_path, 404);
        $disk = Storage::disk($user->avatar_disk ?: config('filesystems.community_media_disk', 'public'));
        abort_unless($disk->exists($user->avatar_path), 404);

        return response()->stream(function () use ($disk, $user): void {
            $stream = $disk->readStream($user->avatar_path);
            abort_if($stream === false, 404);
            fpassthru($stream);
            fclose($stream);
        }, 200, [
            'Content-Type' => $user->avatar_mime_type ?: 'image/jpeg',
            'Content-Length' => (string) $disk->size($user->avatar_path),
            'Cache-Control' => 'public, max-age=3600',
        ]);
    }

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
        $identity = Arr::only($data, ['first_name', 'last_name', 'username']);
        $profileData = Arr::except($data, ['first_name', 'last_name', 'username']);
        $profileData['user_id'] = $user->id;
        $profileData['bmi'] = $this->computeBmi($profileData['weight_kg'], $profileData['height_cm']);

        $profile = DB::transaction(function () use ($user, $identity, $profileData) {
            if ($identity !== []) {
                $user->update($identity);
            }
            return $user->profile()->create($profileData);
        });

        return $this->createdResponse($this->profileWithName($profile));
    }

    /**
     * Update the authenticated user's profile.
     */
    public function update(UpdateProfileRequest $request): JsonResponse
    {
        $user = auth()->user();
        $profile = $user->profile;

        if (!$profile) {
            return $this->errorResponse('No profile exists', 404);
        }

        $data = $request->validated();
        $identity = Arr::only($data, ['first_name', 'last_name', 'username']);
        $data = Arr::except($data, ['first_name', 'last_name', 'username']);
        $preferenceChanged = array_key_exists('workout_preference', $data)
            && $data['workout_preference'] !== $profile->workout_preference;
        $oldAvailability = collect($profile->availability_days ?? [])->map('strtolower');
        $newAvailability = collect($data['availability_days'] ?? $profile->availability_days ?? [])->map('strtolower');
        $availabilityChanged = $oldAvailability->sort()->values()->all()
            !== $newAvailability->sort()->values()->all();
        $availabilityOnlyRemoved = $availabilityChanged
            && $newAvailability->diff($oldAvailability)->isEmpty();
        $recommendationContextChanged = $preferenceChanged || $availabilityChanged;

        // Recompute BMI if height or weight changed
        $heightCm = $data['height_cm'] ?? $profile->height_cm;
        $weightKg = $data['weight_kg'] ?? $profile->weight_kg;

        if (isset($data['height_cm']) || isset($data['weight_kg'])) {
            $data['bmi'] = $this->computeBmi($weightKg, $heightCm);
        }

        DB::transaction(function () use ($user, $profile, $identity, $data): void {
            if ($identity !== []) {
                $user->update($identity);
            }
            $profile->update($data);
        });
        $profile->refresh();

        // Removing days can safely prune the accepted schedule. Environment
        // changes or added days require a newly generated recommendation.
        if ($preferenceChanged || ($availabilityChanged && !$availabilityOnlyRemoved)) {
            Workout::where('user_id', $profile->user_id)
                ->where('is_generated', true)
                ->delete();
        } elseif ($availabilityOnlyRemoved) {
            $dayNumbers = $newAvailability->map(fn (string $day): ?int => match ($day) {
                'monday' => 1,
                'tuesday' => 2,
                'wednesday' => 3,
                'thursday' => 4,
                'friday' => 5,
                'saturday' => 6,
                'sunday' => 7,
                default => null,
            })->filter()->values()->all();
            Workout::where('user_id', $profile->user_id)
                ->where('is_generated', true)
                ->whereNotIn('day_of_week', $dayNumbers)
                ->delete();
        }

        if (!$recommendationContextChanged &&
            (array_key_exists('fitness_level', $data) || array_key_exists('goal', $data))) {
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
        $data['username'] = $user->username;
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
