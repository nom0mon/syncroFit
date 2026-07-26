<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegisterTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_with_valid_data(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(201)
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
                        'name' => 'John Doe',
                        'email' => 'john@example.com',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'john@example.com',
            'name' => 'John Doe',
        ]);
    }

    public function test_register_returns_422_for_duplicate_email(): void
    {
        User::factory()->create(['email' => 'existing@example.com']);

        $response = $this->postJson('/api/register', [
            'name' => 'Another User',
            'email' => 'existing@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['email']);
    }

    public function test_register_returns_422_for_invalid_name(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => '',
            'email' => 'valid@example.com',
            'password' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['name']);
    }

    public function test_register_returns_422_for_invalid_email(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'John Doe',
            'email' => 'not-an-email',
            'password' => 'password123',
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['email']);
    }

    public function test_register_returns_422_for_short_password(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'short',
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['password']);
    }

    public function test_register_returns_422_for_long_password(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => str_repeat('a', 129),
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['password']);
    }
}
