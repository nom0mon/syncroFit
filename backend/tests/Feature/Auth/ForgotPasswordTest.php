<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class ForgotPasswordTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_returns_200_for_existing_email(): void
    {
        config(['services.brevo.key' => 'test-key']);
        Http::fake(['api.brevo.com/*' => Http::response(['messageId' => 'test'], 201)]);
        User::factory()->create(['email' => 'user@example.com']);

        $response = $this->postJson('/api/forgot-password', [
            'email' => 'user@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Request successful. If an account uses that email, reset instructions have been sent.',
            ]);

        Http::assertSent(fn ($request) =>
            $request->url() === 'https://api.brevo.com/v3/smtp/email'
            && $request->hasHeader('api-key', 'test-key')
            && $request['to'][0]['email'] === 'user@example.com'
            && str_contains($request['htmlContent'], '/reset-password/')
        );
    }

    public function test_forgot_password_returns_200_for_nonexistent_email(): void
    {
        config(['services.brevo.key' => 'test-key']);
        Http::fake();
        $response = $this->postJson('/api/forgot-password', [
            'email' => 'nobody@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Request successful. If an account uses that email, reset instructions have been sent.',
            ]);

        Http::assertNothingSent();
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

    public function test_emailed_token_can_reset_password_and_revoke_existing_tokens(): void
    {
        $user = User::factory()->create([
            'email' => 'user@example.com',
            'password' => 'OldPassword123!',
        ]);
        $user->createToken('mobile');
        $token = Password::createToken($user);

        $this->post('/reset-password', [
            'token' => $token,
            'email' => $user->email,
            'password' => 'NewPassword123!',
            'password_confirmation' => 'NewPassword123!',
        ])->assertRedirect(route('password.reset.complete'));

        $this->assertTrue(Hash::check('NewPassword123!', $user->fresh()->password));
        $this->assertSame(0, $user->tokens()->count());
    }

    public function test_reset_link_displays_the_password_form(): void
    {
        $user = User::factory()->create(['email' => 'user@example.com']);
        $token = Password::createToken($user);

        $this->get(route('password.reset', [
            'token' => $token,
            'email' => $user->email,
        ]))->assertOk()
            ->assertSee('Reset your password')
            ->assertSee('user@example.com');
    }

    public function test_email_provider_failure_returns_a_clear_message(): void
    {
        config(['services.brevo.key' => 'test-key']);
        Http::fake(['api.brevo.com/*' => Http::response(['message' => 'Unavailable'], 503)]);
        User::factory()->create(['email' => 'user@example.com']);

        $this->postJson('/api/forgot-password', ['email' => 'user@example.com'])
            ->assertStatus(503)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Reset instructions could not be sent right now. Please try again later.');
    }
}
