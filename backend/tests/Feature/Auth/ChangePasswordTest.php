<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ChangePasswordTest extends TestCase
{
    use RefreshDatabase;

    private function createUser(string $password = 'password123'): User
    {
        return User::factory()->create([
            'email' => 'user@example.com',
            'password' => Hash::make($password),
        ]);
    }

    public function test_user_can_change_password_with_valid_data(): void
    {
        $user = $this->createUser('password123');
        $token = $user->createToken('auth_token')->plainTextToken;

        $response = $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->putJson('/api/user/password', [
                'current_password' => 'password123',
                'new_password' => 'new-password456',
                'new_password_confirmation' => 'new-password456',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Password changed successfully.',
            ]);

        // The new password must now be accepted for login.
        $user->refresh();
        $this->assertTrue(Hash::check('new-password456', $user->password));
        $this->assertFalse(Hash::check('password123', $user->password));
    }

    public function test_change_password_returns_422_for_incorrect_current_password(): void
    {
        $user = $this->createUser('password123');
        $token = $user->createToken('auth_token')->plainTextToken;

        $response = $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->putJson('/api/user/password', [
                'current_password' => 'wrong-password',
                'new_password' => 'new-password456',
                'new_password_confirmation' => 'new-password456',
            ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['current_password']);

        // Password must remain unchanged.
        $user->refresh();
        $this->assertTrue(Hash::check('password123', $user->password));
    }

    public function test_change_password_returns_422_for_short_new_password(): void
    {
        $user = $this->createUser('password123');
        $token = $user->createToken('auth_token')->plainTextToken;

        $response = $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->putJson('/api/user/password', [
                'current_password' => 'password123',
                'new_password' => 'short',
                'new_password_confirmation' => 'short',
            ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['new_password']);
    }

    public function test_change_password_returns_422_for_long_new_password(): void
    {
        $user = $this->createUser('password123');
        $token = $user->createToken('auth_token')->plainTextToken;

        $response = $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->putJson('/api/user/password', [
                'current_password' => 'password123',
                'new_password' => str_repeat('a', 129),
                'new_password_confirmation' => str_repeat('a', 129),
            ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['new_password']);
    }

    public function test_change_password_returns_422_for_mismatched_confirmation(): void
    {
        $user = $this->createUser('password123');
        $token = $user->createToken('auth_token')->plainTextToken;

        $response = $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->putJson('/api/user/password', [
                'current_password' => 'password123',
                'new_password' => 'new-password456',
                'new_password_confirmation' => 'different-password',
            ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['new_password']);
    }

    public function test_change_password_returns_422_when_new_password_same_as_current(): void
    {
        $user = $this->createUser('password123');
        $token = $user->createToken('auth_token')->plainTextToken;

        $response = $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->putJson('/api/user/password', [
                'current_password' => 'password123',
                'new_password' => 'password123',
                'new_password_confirmation' => 'password123',
            ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['new_password']);
    }

    public function test_change_password_returns_422_for_missing_fields(): void
    {
        $user = $this->createUser('password123');
        $token = $user->createToken('auth_token')->plainTextToken;

        $response = $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->putJson('/api/user/password', []);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors(['current_password', 'new_password']);
    }

    public function test_change_password_returns_401_without_token(): void
    {
        $response = $this->putJson('/api/user/password', [
            'current_password' => 'password123',
            'new_password' => 'new-password456',
            'new_password_confirmation' => 'new-password456',
        ]);

        $response->assertStatus(401)
            ->assertJson(['success' => false]);
    }

    public function test_current_token_remains_valid_after_password_change(): void
    {
        $user = $this->createUser('password123');
        $token = $user->createToken('auth_token')->plainTextToken;

        $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->putJson('/api/user/password', [
                'current_password' => 'password123',
                'new_password' => 'new-password456',
                'new_password_confirmation' => 'new-password456',
            ])->assertStatus(200);

        // The current token should still authenticate a subsequent request.
        $this->withHeaders(['Authorization' => "Bearer {$token}"])
            ->postJson('/api/logout')
            ->assertStatus(200);
    }

    public function test_other_tokens_are_revoked_after_password_change(): void
    {
        $user = $this->createUser('password123');
        $currentToken = $user->createToken('current_device')->plainTextToken;
        $otherToken = $user->createToken('other_device')->plainTextToken;

        $this->assertDatabaseCount('personal_access_tokens', 2);

        $this->withHeaders(['Authorization' => "Bearer {$currentToken}"])
            ->putJson('/api/user/password', [
                'current_password' => 'password123',
                'new_password' => 'new-password456',
                'new_password_confirmation' => 'new-password456',
            ])->assertStatus(200);

        // Only the current token remains.
        $this->assertDatabaseCount('personal_access_tokens', 1);

        // The other device's token is no longer accepted.
        $this->withHeaders(['Authorization' => "Bearer {$otherToken}"])
            ->postJson('/api/logout')
            ->assertStatus(401);
    }
}
