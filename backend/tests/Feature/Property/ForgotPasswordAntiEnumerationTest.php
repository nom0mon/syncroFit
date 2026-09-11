<?php

namespace Tests\Feature\Property;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Property Test: Forgot-Password Anti-Enumeration (Property 6)
 *
 * For random valid-format emails (some existing, some not), verify
 * identical 200 response structure regardless of whether the email exists.
 *
 * **Validates: Requirements 3.2**
 */
class ForgotPasswordAntiEnumerationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Generate a random valid-format email address.
     */
    private function generateRandomEmail(): string
    {
        $localPartLength = mt_rand(3, 20);
        $domainPartLength = mt_rand(3, 10);
        $tldLength = mt_rand(2, 5);

        $chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

        $local = '';
        for ($i = 0; $i < $localPartLength; $i++) {
            $local .= $chars[mt_rand(0, strlen($chars) - 1)];
        }

        $domain = '';
        for ($i = 0; $i < $domainPartLength; $i++) {
            $domain .= $chars[mt_rand(0, strlen($chars) - 1)];
        }

        $tld = '';
        for ($i = 0; $i < $tldLength; $i++) {
            $tld .= 'abcdefghijklmnopqrstuvwxyz'[mt_rand(0, 25)];
        }

        return "{$local}@{$domain}.{$tld}";
    }

    /**
     * Property 6: Forgot-Password Anti-Enumeration
     *
     * Generate random valid-format emails (half existing users, half non-existent),
     * verify response is always 200 with identical structure and message.
     *
     * **Validates: Requirements 3.2**
     */
    public function test_forgot_password_anti_enumeration_property(): void
    {
        $iterations = 100;
        config(['services.brevo.key' => 'test-key']);
        Http::fake(['api.brevo.com/*' => Http::response(['messageId' => 'test'], 201)]);
        $expectedMessage = 'Request successful. If an account uses that email, reset instructions have been sent.';

        // Collect all responses to compare structure
        $responses = [];

        for ($i = 0; $i < $iterations; $i++) {
            // Clear rate limiter for each iteration to avoid 429 interference
            $email = $this->generateRandomEmail();
            RateLimiter::clear('forgot-password|' . strtolower($email));

            // Half the iterations use existing users, half use non-existent emails
            $isExistingUser = $i < ($iterations / 2);

            if ($isExistingUser) {
                User::factory()->create(['email' => $email]);
            }

            $response = $this->postJson('/api/forgot-password', [
                'email' => $email,
            ]);

            // Every response must be 200 regardless of email existence
            $response->assertStatus(200);

            $json = $response->json();

            // Verify the response structure is identical
            $this->assertTrue(
                $json['success'],
                "Iteration $i: Expected success=true for email '$email' (exists=" . ($isExistingUser ? 'yes' : 'no') . ")"
            );

            $this->assertEquals(
                $expectedMessage,
                $json['message'],
                "Iteration $i: Expected identical message for email '$email' (exists=" . ($isExistingUser ? 'yes' : 'no') . ")"
            );

            // Verify the response has the same keys
            $this->assertArrayHasKey('success', $json, "Iteration $i: Missing 'success' key");
            $this->assertArrayHasKey('data', $json, "Iteration $i: Missing 'data' key");
            $this->assertArrayHasKey('message', $json, "Iteration $i: Missing 'message' key");

            // Verify data is null (no user info leaks)
            $this->assertNull(
                $json['data'],
                "Iteration $i: Expected data=null for email '$email' (exists=" . ($isExistingUser ? 'yes' : 'no') . ")"
            );

            // Store response structure for cross-comparison
            $responses[] = [
                'exists' => $isExistingUser,
                'status' => $response->getStatusCode(),
                'keys' => array_keys($json),
                'success' => $json['success'],
                'message' => $json['message'],
                'data' => $json['data'],
            ];
        }

        // Cross-compare: all responses must have identical structure
        $referenceResponse = $responses[0];
        foreach ($responses as $index => $resp) {
            $this->assertEquals(
                $referenceResponse['status'],
                $resp['status'],
                "Response $index: Status code differs from reference (exists={$resp['exists']})"
            );
            $this->assertEquals(
                $referenceResponse['keys'],
                $resp['keys'],
                "Response $index: JSON keys differ from reference (exists={$resp['exists']})"
            );
            $this->assertEquals(
                $referenceResponse['success'],
                $resp['success'],
                "Response $index: 'success' field differs from reference (exists={$resp['exists']})"
            );
            $this->assertEquals(
                $referenceResponse['message'],
                $resp['message'],
                "Response $index: 'message' field differs from reference (exists={$resp['exists']})"
            );
            $this->assertEquals(
                $referenceResponse['data'],
                $resp['data'],
                "Response $index: 'data' field differs from reference (exists={$resp['exists']})"
            );
        }
    }
}
