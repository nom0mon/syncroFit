<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_login_with_valid_credentials(): void
    {
        User::factory()->create([
            'email' => 'user@example.com',
            'password' => bcrypt('password123'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'user@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'user' => ['id', 'name', 'email'],
                    'token',
                ],
                'message',
            ])
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'email' => 'user@example.com',
                    ],
                ],
            ]);
    }

    public function test_login_returns_401_for_wrong_password(): void
    {
        User::factory()->create([
            'email' => 'user@example.com',
            'password' => bcrypt('password123'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'user@example.com',
            'password' => 'wrongpassword',
        ]);

        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
                'message' => 'Invalid email or password',
            ]);
    }

    public function test_login_returns_401_for_nonexistent_email(): void
    {
        $response = $this->postJson('/api/login', [
            'email' => 'nobody@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
                'message' => 'Invalid email or password',
            ]);
    }

    public function test_login_returns_422_for_invalid_email_format(): void
    {
        $response = $this->postJson('/api/login', [
            'email' => 'not-valid-email',
            'password' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['email']);
    }

    public function test_login_returns_422_for_short_password(): void
    {
        $response = $this->postJson('/api/login', [
            'email' => 'user@example.com',
            'password' => 'short',
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['password']);
    }
}
