<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LogoutTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_logout(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/logout');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Successfully logged out.',
            ]);
    }

    public function test_logout_returns_401_without_token(): void
    {
        $response = $this->postJson('/api/logout');

        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
            ]);
    }

    public function test_token_is_revoked_after_logout(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('auth_token')->plainTextToken;

        // Logout using the token
        $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->postJson('/api/logout')
            ->assertStatus(200);

        // Attempt to access a protected route with the same token
        $response = $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->postJson('/api/logout');

        $response->assertStatus(401);
    }
}
