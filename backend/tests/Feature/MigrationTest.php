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
            'availability_days', 'bmi', 'created_at', 'updated_at',
        ]));
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
            'estimated_duration_minutes', 'exercises', 'is_generated',
            'created_at', 'updated_at',
        ]));
    }

    public function test_workout_history_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('workout_history'));
        $this->assertTrue(Schema::hasColumns('workout_history', [
            'id', 'user_id', 'workout_name', 'completed_at',
            'total_duration_seconds', 'exercises_completed',
            'created_at', 'updated_at',
        ]));
    }

    public function test_obsolete_tables_do_not_exist(): void
    {
        $this->assertFalse(Schema::hasTable('sessions'));
        $this->assertFalse(Schema::hasTable('cache'));
        $this->assertFalse(Schema::hasTable('cache_locks'));
        $this->assertFalse(Schema::hasTable('recommendations'));
        $this->assertFalse(Schema::hasTable('workout_exercises'));
        $this->assertFalse(Schema::hasTable('workout_sessions'));
        $this->assertFalse(Schema::hasTable('session_exercises'));
        $this->assertFalse(Schema::hasTable('progress_records'));
        $this->assertFalse(Schema::hasTable('device_tokens'));
    }
}
