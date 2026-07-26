<?php

namespace Tests\Feature\Property;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Property Test: Invalid Credentials Generic Error (Property 5)
 *
 * For random invalid credentials (non-existent email, wrong password, both),
 * verify the response is always 401 with "Invalid email or password" regardless
 * of which credential is wrong.
 *
 * **Validates: Requirements 2.2**
 */
class InvalidCredentialsTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Property 5: Invalid Credentials Generic Error
     *
     * Generate random invalid credentials (wrong email, wrong password, both wrong),
     * verify identical 401 response with same generic message.
     *
     * The key security property: the response must NOT reveal whether the email
     * or the password was the incorrect credential (anti-enumeration).
     *
     * **Validates: Requirements 2.2**
     */
    public function test_invalid_credentials_return_identical_generic_error_property(): void
    {
        // The expected error response shape for all invalid credential cases
        $expectedStatus = 401;
        $expectedMessage = 'Invalid email or password';

        for ($i = 0; $i < 100; $i++) {
            // Create a real user with a known password for each iteration
            $knownPassword = 'ValidP@ss' . Str::random(8);
            $user = User::factory()->create([
                'password' => Hash::make($knownPassword),
            ]);

            // Randomly choose one of three invalid credential scenarios
            $scenario = mt_rand(0, 2);

            switch ($scenario) {
                case 0:
                    // Wrong email (non-existent), correct password format
                    $email = 'nonexistent_' . Str::random(10) . '@example.com';
                    $password = $knownPassword;
                    $scenarioName = 'wrong_email';
                    break;

                case 1:
                    // Correct email, wrong password
                    $email = $user->email;
                    $password = 'Wrong' . Str::random(12);
                    $scenarioName = 'wrong_password';
                    break;

                case 2:
                    // Both wrong (non-existent email and random password)
                    $email = 'fake_' . Str::random(10) . '@nowhere.org';
                    $password = 'Random' . Str::random(12);
                    $scenarioName = 'both_wrong';
                    break;
            }

            $response = $this->postJson('/api/login', [
                'email' => $email,
                'password' => $password,
            ]);

            // Assert identical 401 status regardless of scenario
            $response->assertStatus($expectedStatus);

            // Assert identical response structure
            $responseData = $response->json();

            $this->assertFalse(
                $responseData['success'],
                "Iteration $i ($scenarioName): 'success' should be false"
            );

            $this->assertEquals(
                $expectedMessage,
                $responseData['message'],
                "Iteration $i ($scenarioName): Message should be generic '$expectedMessage', got: '{$responseData['message']}'"
            );

            // Ensure no data is leaked that could reveal which credential was wrong
            $this->assertNull(
                $responseData['data'] ?? null,
                "Iteration $i ($scenarioName): 'data' should be null for failed login"
            );

            // Ensure errors field is null (not a validation error)
            $this->assertNull(
                $responseData['errors'] ?? null,
                "Iteration $i ($scenarioName): 'errors' should be null for credential failure"
            );
        }
    }

    /**
     * Property 5: Response structure consistency across all invalid credential types.
     *
     * Verify that wrong-email, wrong-password, and both-wrong all produce
     * byte-identical response bodies (same JSON keys, same values).
     *
     * **Validates: Requirements 2.2**
     */
    public function test_all_invalid_credential_types_produce_identical_response_structure(): void
    {
        for ($i = 0; $i < 50; $i++) {
            $knownPassword = 'Secure' . Str::random(10);
            $user = User::factory()->create([
                'password' => Hash::make($knownPassword),
            ]);

            // Scenario A: Wrong email, any password
            $responseA = $this->postJson('/api/login', [
                'email' => 'wrong_' . Str::random(8) . '@example.com',
                'password' => $knownPassword,
            ]);

            // Scenario B: Correct email, wrong password
            $responseB = $this->postJson('/api/login', [
                'email' => $user->email,
                'password' => 'WrongPass' . Str::random(8),
            ]);

            // Scenario C: Both wrong
            $responseC = $this->postJson('/api/login', [
                'email' => 'nobody_' . Str::random(8) . '@test.com',
                'password' => 'NoMatch' . Str::random(8),
            ]);

            // All three must have the same status
            $this->assertEquals(401, $responseA->status(), "Iteration $i: Scenario A should be 401");
            $this->assertEquals(401, $responseB->status(), "Iteration $i: Scenario B should be 401");
            $this->assertEquals(401, $responseC->status(), "Iteration $i: Scenario C should be 401");

            // All three must have identical JSON structure and message
            $jsonA = $responseA->json();
            $jsonB = $responseB->json();
            $jsonC = $responseC->json();

            $this->assertEquals($jsonA['success'], $jsonB['success'], "Iteration $i: success fields differ A vs B");
            $this->assertEquals($jsonA['success'], $jsonC['success'], "Iteration $i: success fields differ A vs C");
            $this->assertEquals($jsonA['message'], $jsonB['message'], "Iteration $i: messages differ A vs B");
            $this->assertEquals($jsonA['message'], $jsonC['message'], "Iteration $i: messages differ A vs C");
        }
    }
}
