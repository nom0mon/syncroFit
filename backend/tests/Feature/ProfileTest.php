<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    private function validProfileData(): array
    {
        return [
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ];
    }

    public function test_user_can_create_profile(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/profile', $this->validProfileData());

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.age', 25)
            ->assertJsonPath('data.height_cm', '175.00')
            ->assertJsonPath('data.weight_kg', '70.00')
            ->assertJsonPath('data.gender', 'male')
            ->assertJsonPath('data.goal', 'build_muscle')
            ->assertJsonPath('data.fitness_level', 'intermediate')
            ->assertJsonPath('data.workout_preference', 'gym')
            ->assertJsonPath('data.availability_days', ['monday', 'wednesday', 'friday'])
            ->assertJsonPath('data.bmi', '22.86');

        $this->assertDatabaseHas('profiles', [
            'user_id' => $user->id,
            'age' => 25,
        ]);
    }

    public function test_create_profile_returns_409_if_already_exists(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Create profile first
        $user->profile()->create(array_merge($this->validProfileData(), [
            'bmi' => 22.86,
        ]));

        // Try to create again
        $response = $this->postJson('/api/profile', $this->validProfileData());

        $response->assertStatus(409)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'Profile already exists');
    }

    public function test_create_profile_returns_422_for_invalid_data(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/profile', [
            'age' => 10,          // below min 13
            'height_cm' => 30,    // below min 50
            'weight_kg' => 10,    // below min 20
            'gender' => 'invalid',
            'goal' => 'invalid_goal',
            'fitness_level' => 'expert',
            'workout_preference' => 'pool',
            'availability_days' => [],
        ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false])
            ->assertJsonValidationErrors([
                'age',
                'height_cm',
                'weight_kg',
                'gender',
                'goal',
                'fitness_level',
                'workout_preference',
                'availability_days',
            ]);
    }

    public function test_user_can_show_profile(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $user->profile()->create(array_merge($this->validProfileData(), [
            'bmi' => 22.86,
        ]));

        $response = $this->getJson('/api/profile');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.age', 25)
            ->assertJsonPath('data.height_cm', '175.00')
            ->assertJsonPath('data.weight_kg', '70.00')
            ->assertJsonPath('data.gender', 'male')
            ->assertJsonPath('data.goal', 'build_muscle')
            ->assertJsonPath('data.fitness_level', 'intermediate')
            ->assertJsonPath('data.workout_preference', 'gym')
            ->assertJsonPath('data.bmi', '22.86');
    }

    public function test_show_profile_returns_404_if_none_exists(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/profile');

        $response->assertStatus(404)
            ->assertJsonPath('success', false)
            ->assertJsonPath('message', 'No profile exists');
    }

    public function test_user_can_update_profile(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $user->profile()->create(array_merge($this->validProfileData(), [
            'bmi' => 22.86,
        ]));

        $response = $this->putJson('/api/profile', [
            'age' => 30,
            'goal' => 'lose_weight',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.age', 30)
            ->assertJsonPath('data.goal', 'lose_weight')
            // unchanged fields remain
            ->assertJsonPath('data.height_cm', '175.00')
            ->assertJsonPath('data.weight_kg', '70.00')
            ->assertJsonPath('data.bmi', '22.86');
    }

    public function test_user_can_customize_a_unique_username_with_profile(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create(['username' => 'already.used']);
        Sanctum::actingAs($user);
        $user->profile()->create(array_merge($this->validProfileData(), ['bmi' => 22.86]));

        $this->putJson('/api/profile', [
            'first_name' => str_repeat('N', 80),
            'last_name' => str_repeat('L', 80),
            'username' => 'My.Unique_Name',
        ])->assertOk()
            ->assertJsonPath('data.username', 'my.unique_name');

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'username' => 'my.unique_name',
            'first_name' => str_repeat('N', 80),
        ]);

        $this->putJson('/api/profile', ['username' => $other->username])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['username']);
    }

    public function test_update_recomputes_bmi_when_weight_changes(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $user->profile()->create(array_merge($this->validProfileData(), [
            'bmi' => 22.86,
        ]));

        // Update weight from 70 to 80
        $response = $this->putJson('/api/profile', [
            'weight_kg' => 80,
        ]);

        // BMI = 80 / (1.75)^2 = 80 / 3.0625 = 26.122... -> 26.12
        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.weight_kg', '80.00')
            ->assertJsonPath('data.bmi', '26.12');
    }

    public function test_update_recomputes_bmi_when_height_changes(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $user->profile()->create(array_merge($this->validProfileData(), [
            'bmi' => 22.86,
        ]));

        // Update height from 175 to 180
        $response = $this->putJson('/api/profile', [
            'height_cm' => 180,
        ]);

        // BMI = 70 / (1.80)^2 = 70 / 3.24 = 21.604... -> 21.60
        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.height_cm', '180.00')
            ->assertJsonPath('data.bmi', '21.60');
    }

    public function test_bmi_computation_correctness(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/profile', $this->validProfileData());

        // BMI = 70 / (175/100)^2 = 70 / (1.75)^2 = 70 / 3.0625 = 22.857... -> 22.86
        $response->assertStatus(201)
            ->assertJsonPath('data.bmi', '22.86');

        // Verify with exact computation
        $expectedBmi = round(70 / pow(175 / 100, 2), 2);
        $this->assertEquals(22.86, $expectedBmi);
        $this->assertEquals('22.86', $response->json('data.bmi'));
    }

    public function test_unauthenticated_request_returns_401(): void
    {
        // GET profile without auth
        $response = $this->getJson('/api/profile');
        $response->assertStatus(401);

        // POST profile without auth
        $response = $this->postJson('/api/profile', $this->validProfileData());
        $response->assertStatus(401);

        // PUT profile without auth
        $response = $this->putJson('/api/profile', ['age' => 30]);
        $response->assertStatus(401);
    }
}
