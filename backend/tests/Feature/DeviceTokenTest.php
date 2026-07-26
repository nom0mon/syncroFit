<?php

namespace Tests\Feature;

use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DeviceTokenTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_device_token(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/device-tokens', [
            'token' => 'fcm-token-abc123',
            'device_id' => 'device-001',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.token', 'fcm-token-abc123')
            ->assertJsonPath('data.device_id', 'device-001')
            ->assertJsonPath('data.user_id', $user->id);

        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $user->id,
            'token' => 'fcm-token-abc123',
            'device_id' => 'device-001',
        ]);
    }

    public function test_device_token_is_replaced_on_same_device_id(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Register first token
        $this->postJson('/api/device-tokens', [
            'token' => 'old-token',
            'device_id' => 'device-001',
        ]);

        // Register new token with same device_id
        $response = $this->postJson('/api/device-tokens', [
            'token' => 'new-token',
            'device_id' => 'device-001',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.token', 'new-token');

        // Only 1 record should exist for this user+device
        $this->assertCount(1, DeviceToken::where('user_id', $user->id)->where('device_id', 'device-001')->get());
        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $user->id,
            'token' => 'new-token',
            'device_id' => 'device-001',
        ]);
        $this->assertDatabaseMissing('device_tokens', [
            'user_id' => $user->id,
            'token' => 'old-token',
        ]);
    }

    public function test_different_device_ids_create_separate_records(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Register token for device A
        $this->postJson('/api/device-tokens', [
            'token' => 'token-a',
            'device_id' => 'device-a',
        ]);

        // Register token for device B
        $this->postJson('/api/device-tokens', [
            'token' => 'token-b',
            'device_id' => 'device-b',
        ]);

        // Should have 2 separate records
        $this->assertCount(2, DeviceToken::where('user_id', $user->id)->get());
        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $user->id,
            'token' => 'token-a',
            'device_id' => 'device-a',
        ]);
        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $user->id,
            'token' => 'token-b',
            'device_id' => 'device-b',
        ]);
    }

    public function test_unauthenticated_request_returns_401(): void
    {
        $response = $this->postJson('/api/device-tokens', [
            'token' => 'fcm-token-abc123',
            'device_id' => 'device-001',
        ]);

        $response->assertStatus(401);
    }

    public function test_validation_requires_token_and_device_id(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Missing both fields
        $response = $this->postJson('/api/device-tokens', []);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['token', 'device_id']);

        // Missing token
        $response = $this->postJson('/api/device-tokens', [
            'device_id' => 'device-001',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['token']);

        // Missing device_id
        $response = $this->postJson('/api/device-tokens', [
            'token' => 'fcm-token-abc123',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['device_id']);
    }
}
