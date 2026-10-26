<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class MigrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_users_table_exists(): void
    {
        $this->assertTrue(Schema::hasTable('users'));
        $this->assertTrue(Schema::hasColumns('users', [
            'id', 'first_name', 'last_name', 'email', 'password', 'created_at', 'updated_at',
        ]));
        $this->assertFalse(Schema::hasColumn('users', 'email_verified_at'));
        $this->assertFalse(Schema::hasColumn('users', 'remember_token'));
    }

    public function test_profiles_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('profiles'));
        $this->assertTrue(Schema::hasColumns('profiles', [
            'id', 'user_id', 'age', 'height_cm', 'weight_kg',
            'gender', 'goal', 'fitness_level', 'workout_preference',
            'created_at', 'updated_at',
        ]));
        // Normalized to 3NF: availability_days moved to profile_availability,
        // bmi is now a computed accessor (no stored column).
        $this->assertFalse(Schema::hasColumn('profiles', 'availability_days'));
        $this->assertFalse(Schema::hasColumn('profiles', 'bmi'));
    }

    public function test_exercises_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('exercises'));
        $this->assertTrue(Schema::hasColumns('exercises', [
            'id', 'name', 'description', 'instructions', 'muscle_group',
            'equipment', 'difficulty', 'default_sets', 'default_reps',
            'default_duration_seconds', 'video_path', 'created_at', 'updated_at',
        ]));
    }

    public function test_workouts_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('workouts'));
        $this->assertTrue(Schema::hasColumns('workouts', [
            'id', 'user_id', 'name', 'day_of_week',
            'estimated_duration_minutes', 'is_generated',
            'created_at', 'updated_at',
        ]));
        // Normalized to 3NF: exercises moved to the workout_exercises table.
        $this->assertFalse(Schema::hasColumn('workouts', 'exercises'));
    }

    public function test_workout_history_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('workout_history'));
        $this->assertTrue(Schema::hasColumns('workout_history', [
            'id', 'user_id', 'workout_name', 'completed_at',
            'total_duration_seconds', 'created_at', 'updated_at',
        ]));
        // Normalized to 3NF: moved to the workout_history_exercises table.
        $this->assertFalse(Schema::hasColumn('workout_history', 'exercises_completed'));
    }

    public function test_normalized_3nf_tables_are_created(): void
    {
        $this->assertTrue(Schema::hasTable('profile_availability'));
        $this->assertTrue(Schema::hasColumns('profile_availability', [
            'id', 'profile_id', 'day_of_week', 'created_at', 'updated_at',
        ]));

        $this->assertTrue(Schema::hasTable('workout_exercises'));
        $this->assertTrue(Schema::hasColumns('workout_exercises', [
            'id', 'workout_id', 'exercise_id', 'sets', 'reps',
            'duration_seconds', 'rest_seconds', 'position',
            'created_at', 'updated_at',
        ]));

        $this->assertTrue(Schema::hasTable('workout_history_exercises'));
        $this->assertTrue(Schema::hasColumns('workout_history_exercises', [
            'id', 'workout_history_id', 'exercise_id', 'exercise_name',
            'sets_completed', 'reps_or_duration', 'is_duration', 'position',
            'created_at', 'updated_at',
        ]));
    }

    public function test_obsolete_tables_do_not_exist(): void
    {
        $this->assertFalse(Schema::hasTable('sessions'));
        $this->assertFalse(Schema::hasTable('cache'));
        $this->assertFalse(Schema::hasTable('cache_locks'));
        $this->assertFalse(Schema::hasTable('recommendations'));
        // Note: workout_exercises is reintroduced by the 3NF normalization
        // and is intentionally present (asserted above).
        $this->assertFalse(Schema::hasTable('workout_sessions'));
        $this->assertFalse(Schema::hasTable('session_exercises'));
        $this->assertFalse(Schema::hasTable('progress_records'));
        $this->assertFalse(Schema::hasTable('device_tokens'));
    }
}
