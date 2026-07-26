<?php

namespace App\Services;

use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class NotificationService
{
    /**
     * Send a workout reminder notification to a user.
     * Includes workout name and scheduled time in the payload.
     */
    public function sendWorkoutReminder(User $user, string $workoutName, string $scheduledTime): void
    {
        $tokens = $this->getUserTokens($user);
        if (empty($tokens)) {
            return;
        }

        $payload = [
            'title' => 'Workout Reminder',
            'body' => "Your workout \"$workoutName\" starts at $scheduledTime",
            'data' => [
                'type' => 'workout_reminder',
                'workout_name' => $workoutName,
                'scheduled_time' => $scheduledTime,
            ],
        ];

        $this->sendToTokens($tokens, $payload);
    }

    /**
     * Send a system notification to a user (plan updates, milestones, etc.)
     */
    public function sendSystemNotification(User $user, string $title, string $body, array $data = []): void
    {
        $tokens = $this->getUserTokens($user);
        if (empty($tokens)) {
            return;
        }

        $payload = [
            'title' => $title,
            'body' => $body,
            'data' => array_merge(['type' => 'system'], $data),
        ];

        $this->sendToTokens($tokens, $payload);
    }

    /**
     * Get all FCM tokens for a user.
     */
    private function getUserTokens(User $user): array
    {
        return DeviceToken::where('user_id', $user->id)
            ->pluck('token')
            ->toArray();
    }

    /**
     * Send a notification payload to FCM for the given tokens.
     * Uses Firebase Cloud Messaging HTTP v1 API.
     */
    private function sendToTokens(array $tokens, array $payload): void
    {
        $serverKey = config('services.fcm.server_key');
        if (empty($serverKey)) {
            Log::warning('FCM server key not configured. Notification not sent.');
            return;
        }

        foreach ($tokens as $token) {
            try {
                Http::withHeaders([
                    'Authorization' => 'key=' . $serverKey,
                    'Content-Type' => 'application/json',
                ])->post('https://fcm.googleapis.com/fcm/send', [
                    'to' => $token,
                    'notification' => [
                        'title' => $payload['title'],
                        'body' => $payload['body'],
                    ],
                    'data' => $payload['data'] ?? [],
                ]);
            } catch (\Exception $e) {
                Log::error("Failed to send FCM notification to token: $token", [
                    'error' => $e->getMessage(),
                ]);
            }
        }
    }
}
