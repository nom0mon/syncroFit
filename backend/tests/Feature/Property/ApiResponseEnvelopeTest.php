<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Property Test: Consistent API Response Envelope (Property 20)
 *
 * Hit various endpoints with valid/invalid data, verify all responses conform
 * to the envelope structure with correct Content-Type header.
 *
 * Success responses: {"success": true, "data": ..., "message": ...}
 * Error responses: {"success": false, "message": ..., "errors": ...}
 * All responses must have Content-Type: application/json
 *
 * **Validates: Requirements 12.1, 12.2, 12.3, 12.4**
 */
class ApiResponseEnvelopeTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Property 20: Consistent API Response Envelope
     *
     * Hit multiple endpoints (register, login, profile, exercises, progress,
     * device-tokens) with both valid and invalid data. Verify every response has:
     * - Content-Type: application/json header
     * - Success responses: {"success": true, "data": ..., "message": ...}
     * - Error responses: {"success": false, "message": ..., "errors": ...}
     *
     * **Validates: Requirements 12.1, 12.2, 12.3, 12.4**
     */
    public function test_all_endpoints_conform_to_response_envelope_property(): void
    {
        // Create test data (override nullable-incompatible factory defaults)
        Exercise::factory()->count(5)->create(['default_duration_seconds' => 60]);
        $user = User::factory()->create([
            'password' => Hash::make('TestPassword123'),
        ]);

        for ($i = 0; $i < 50; $i++) {
            // Randomly pick an endpoint scenario
            $scenario = mt_rand(0, 12);

            $response = match ($scenario) {
                0 => $this->hitRegisterValid(),
                1 => $this->hitRegisterInvalid(),
                2 => $this->hitLoginValid($user),
                3 => $this->hitLoginInvalid(),
                4 => $this->hitForgotPassword(),
                5 => $this->hitProfileAuthed($user),
                6 => $this->hitProfileUnauthed(),
                7 => $this->hitExercisesAuthed($user),
                8 => $this->hitExerciseNotFound($user),
                9 => $this->hitProgressSummaryAuthed($user),
                10 => $this->hitProgressSummaryUnauthed(),
                11 => $this->hitDeviceTokensValid($user),
                12 => $this->hitDeviceTokensInvalid($user),
            };

            // Assert Content-Type header is application/json
            $contentType = $response->headers->get('Content-Type');
            $this->assertNotNull(
                $contentType,
                "Iteration $i (scenario $scenario): Content-Type header must be present"
            );
            $this->assertStringContainsString(
                'application/json',
                $contentType,
                "Iteration $i (scenario $scenario): Content-Type must contain 'application/json', got: $contentType"
            );

            // Assert JSON structure matches the envelope
            $json = $response->json();
            $this->assertIsArray($json, "Iteration $i (scenario $scenario): Response must be valid JSON");
            $this->assertArrayHasKey('success', $json, "Iteration $i (scenario $scenario): Response must have 'success' key");

            $statusCode = $response->status();

            if ($json['success'] === true) {
                // Success envelope: {"success": true, "data": ..., "message": ...}
                $this->assertArrayHasKey(
                    'data',
                    $json,
                    "Iteration $i (scenario $scenario): Success response must have 'data' key"
                );
                $this->assertArrayHasKey(
                    'message',
                    $json,
                    "Iteration $i (scenario $scenario): Success response must have 'message' key"
                );
                $this->assertTrue(
                    in_array($statusCode, [200, 201]),
                    "Iteration $i (scenario $scenario): Success response must have status 200 or 201, got $statusCode"
                );
            } else {
                // Error envelope: {"success": false, "message": ..., "errors": ...}
                $this->assertFalse(
                    $json['success'],
                    "Iteration $i (scenario $scenario): Error response must have 'success' = false"
                );
                $this->assertArrayHasKey(
                    'message',
                    $json,
                    "Iteration $i (scenario $scenario): Error response must have 'message' key"
                );
                $this->assertIsString(
                    $json['message'],
                    "Iteration $i (scenario $scenario): Error response 'message' must be a string"
                );
                $this->assertArrayHasKey(
                    'errors',
                    $json,
                    "Iteration $i (scenario $scenario): Error response must have 'errors' key"
                );
                // errors can be null (non-validation) or object (validation/422)
                if ($statusCode === 422) {
                    $this->assertIsArray(
                        $json['errors'],
                        "Iteration $i (scenario $scenario): 422 response 'errors' must be an object/array"
                    );
                } else {
                    $this->assertNull(
                        $json['errors'],
                        "Iteration $i (scenario $scenario): Non-422 error response 'errors' must be null, got: " . json_encode($json['errors'])
                    );
                }
                $this->assertTrue(
                    in_array($statusCode, [401, 403, 404, 409, 422, 429, 500]),
                    "Iteration $i (scenario $scenario): Error response must have appropriate error status code, got $statusCode"
                );
            }
        }
    }

    // --- Endpoint hit methods ---

    private function hitRegisterValid()
    {
        $payload = [
            'name' => 'User' . Str::random(8),
            'email' => Str::random(10) . '@example.com',
            'password' => 'ValidPass' . Str::random(8),
        ];

        return $this->postJson('/api/register', $payload);
    }

    private function hitRegisterInvalid()
    {
        // Random invalid scenario
        $strategy = mt_rand(0, 2);

        $payload = match ($strategy) {
            0 => ['name' => '', 'email' => 'bad', 'password' => 'short'],  // all invalid
            1 => ['name' => Str::random(60), 'email' => 'valid@test.com', 'password' => 'ValidPass1'], // name too long
            2 => ['email' => 'a@b.com'],  // missing fields
        };

        return $this->postJson('/api/register', $payload);
    }

    private function hitLoginValid(User $user)
    {
        return $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'TestPassword123',
        ]);
    }

    private function hitLoginInvalid()
    {
        $strategy = mt_rand(0, 1);

        return match ($strategy) {
            0 => $this->postJson('/api/login', [
                'email' => 'nonexistent' . Str::random(5) . '@example.com',
                'password' => 'WrongPassword123',
            ]),
            1 => $this->postJson('/api/login', [
                'email' => 'not-an-email',
                'password' => 'hi',  // too short — should get 422
            ]),
        };
    }

    private function hitForgotPassword()
    {
        $strategy = mt_rand(0, 1);

        return match ($strategy) {
            0 => $this->postJson('/api/forgot-password', [
                'email' => Str::random(8) . '@example.com',
            ]),
            1 => $this->postJson('/api/forgot-password', [
                'email' => 'not-valid-email',  // should get 422
            ]),
        };
    }

    private function hitProfileAuthed(User $user)
    {
        Sanctum::actingAs($user);
        return $this->getJson('/api/profile');
    }

    private function hitProfileUnauthed()
    {
        return $this->getJson('/api/profile');
    }

    private function hitExercisesAuthed(User $user)
    {
        Sanctum::actingAs($user);
        $page = mt_rand(1, 3);
        return $this->getJson("/api/exercises?page=$page&page_size=5");
    }

    private function hitExerciseNotFound(User $user)
    {
        Sanctum::actingAs($user);
        return $this->getJson('/api/exercises/99999');
    }

    private function hitProgressSummaryAuthed(User $user)
    {
        Sanctum::actingAs($user);
        return $this->getJson('/api/progress/summary');
    }

    private function hitProgressSummaryUnauthed()
    {
        return $this->getJson('/api/progress/summary');
    }

    private function hitDeviceTokensValid(User $user)
    {
        Sanctum::actingAs($user);
        return $this->postJson('/api/device-tokens', [
            'token' => 'fcm_' . Str::random(30),
            'device_id' => 'device_' . Str::random(10),
        ]);
    }

    private function hitDeviceTokensInvalid(User $user)
    {
        Sanctum::actingAs($user);
        // Missing required fields
        $strategy = mt_rand(0, 1);

        return match ($strategy) {
            0 => $this->postJson('/api/device-tokens', []),  // empty body
            1 => $this->postJson('/api/device-tokens', ['token' => '']),  // empty token, missing device_id
        };
    }
}
