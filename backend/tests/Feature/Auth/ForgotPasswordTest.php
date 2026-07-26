<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

class ForgotPasswordTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_returns_200_for_existing_email(): void
    {
        User::factory()->create(['email' => 'user@example.com']);

        $response = $this->postJson('/api/forgot-password', [
            'email' => 'user@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'If an account with that email exists, a password reset link has been sent.',
            ]);
    }

    public function test_forgot_password_returns_200_for_nonexistent_email(): void
    {
        $response = $this->postJson('/api/forgot-password', [
            'email' => 'nobody@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'If an account with that email exists, a password reset link has been sent.',
            ]);
    }

    public function test_forgot_password_rate_limits_after_5_requests(): void
    {
        RateLimiter::clear('forgot-password|user@example.com');

        // First 5 requests should succeed
        for ($i = 0; $i < 5; $i++) {
            $response = $this->postJson('/api/forgot-password', [
                'email' => 'user@example.com',
            ]);
            $response->assertStatus(200);
        }

        // 6th request should be rate limited
        $response = $this->postJson('/api/forgot-password', [
            'email' => 'user@example.com',
        ]);

        $response->assertStatus(429)
            ->assertJson([
                'success' => false,
            ]);
    }

    public function test_forgot_password_returns_422_for_invalid_email(): void
    {
        $response = $this->postJson('/api/forgot-password', [
            'email' => 'not-an-email',
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['email']);
    }
}
