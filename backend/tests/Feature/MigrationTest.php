<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class MigrationTest extends TestCase
{
    use RefreshDatabase;

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
            'default_duration_seconds', 'image_url', 'created_at', 'updated_at',
        ]));
    }

    public function test_recommendations_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('recommendations'));
        $this->assertTrue(Schema::hasColumns('recommendations', [
            'id', 'user_id', 'week_start', 'plan_data',
            'created_at', 'updated_at',
        ]));
    }

    public function test_workouts_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('workouts'));
        $this->assertTrue(Schema::hasColumns('workouts', [
            'id', 'recommendation_id', 'name', 'day_of_week',
            'estimated_duration_minutes', 'created_at', 'updated_at',
        ]));
    }

    public function test_workout_exercises_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('workout_exercises'));
        $this->assertTrue(Schema::hasColumns('workout_exercises', [
            'id', 'workout_id', 'exercise_id', 'sets', 'reps',
            'rest_seconds', 'order', 'created_at', 'updated_at',
        ]));
    }

    public function test_workout_sessions_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('workout_sessions'));
        $this->assertTrue(Schema::hasColumns('workout_sessions', [
            'id', 'user_id', 'workout_id', 'status', 'started_at',
            'completed_at', 'total_duration_seconds', 'pause_log',
            'created_at', 'updated_at',
        ]));
    }

    public function test_session_exercises_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('session_exercises'));
        $this->assertTrue(Schema::hasColumns('session_exercises', [
            'id', 'workout_session_id', 'exercise_id', 'status',
            'sets_completed', 'reps_completed', 'created_at', 'updated_at',
        ]));
    }

    public function test_progress_records_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('progress_records'));
        $this->assertTrue(Schema::hasColumns('progress_records', [
            'id', 'user_id', 'recorded_at', 'weight_kg', 'bmi',
            'workouts_completed', 'created_at', 'updated_at',
        ]));
    }

    public function test_device_tokens_table_is_created(): void
    {
        $this->assertTrue(Schema::hasTable('device_tokens'));
        $this->assertTrue(Schema::hasColumns('device_tokens', [
            'id', 'user_id', 'token', 'device_id',
            'created_at', 'updated_at',
        ]));
    }

    public function test_users_table_exists(): void
    {
        $this->assertTrue(Schema::hasTable('users'));
        $this->assertTrue(Schema::hasColumns('users', [
            'id', 'name', 'email', 'password', 'created_at', 'updated_at',
        ]));
    }
}
