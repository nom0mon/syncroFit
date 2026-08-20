<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Disable foreign key checks to allow dropping tables in any order
        Schema::disableForeignKeyConstraints();

        // 1. Drop obsolete tables (order no longer matters with FK checks disabled)
        Schema::dropIfExists('session_exercises');
        Schema::dropIfExists('workout_sessions');
        Schema::dropIfExists('workout_exercises');
        Schema::dropIfExists('workouts');
        Schema::dropIfExists('recommendations');
        Schema::dropIfExists('progress_records');
        Schema::dropIfExists('device_tokens');

        // Re-enable foreign key checks
        Schema::enableForeignKeyConstraints();

        // 2. Rename exercises.image_url to video_path
        Schema::table('exercises', function (Blueprint $table) {
            $table->renameColumn('image_url', 'video_path');
        });

        Schema::create('workouts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('name');
            $table->string('day_of_week')->nullable();
            $table->integer('estimated_duration_minutes')->nullable();
            $table->json('exercises');
            $table->boolean('is_generated')->default(false);
            $table->timestamps();

            $table->index('user_id');
        });

        // 4. Create workout_history table
        Schema::create('workout_history', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('workout_name');
            $table->timestamp('completed_at');
            $table->integer('total_duration_seconds');
            $table->json('exercises_completed');
            $table->timestamps();

            $table->index('user_id');
            $table->index('completed_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // 1. Drop the new tables
        Schema::dropIfExists('workout_history');
        Schema::dropIfExists('workouts');

        // 2. Recreate the original workouts table
        Schema::create('workouts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('recommendation_id')->constrained()->onDelete('cascade');
            $table->string('name');
            $table->integer('day_of_week');
            $table->integer('estimated_duration_minutes');
            $table->timestamps();

            $table->index('recommendation_id');
        });

        // 3. Rename video_path back to image_url
        Schema::table('exercises', function (Blueprint $table) {
            $table->renameColumn('video_path', 'image_url');
        });

        // 4. Recreate all dropped tables with original schema
        Schema::create('recommendations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->date('week_start');
            $table->json('plan_data');
            $table->timestamps();

            $table->index('user_id');
        });

        Schema::create('workout_exercises', function (Blueprint $table) {
            $table->id();
            $table->foreignId('workout_id')->constrained()->onDelete('cascade');
            $table->foreignId('exercise_id')->constrained()->onDelete('cascade');
            $table->integer('sets');
            $table->integer('reps');
            $table->integer('rest_seconds');
            $table->integer('order');
            $table->timestamps();

            $table->index('workout_id');
            $table->index('exercise_id');
        });

        Schema::create('workout_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('workout_id')->constrained()->onDelete('cascade');
            $table->string('status');
            $table->timestamp('started_at');
            $table->timestamp('completed_at')->nullable();
            $table->integer('total_duration_seconds')->nullable();
            $table->json('pause_log')->nullable();
            $table->timestamps();

            $table->index('user_id');
            $table->index('workout_id');
            $table->index('completed_at');
        });

        Schema::create('session_exercises', function (Blueprint $table) {
            $table->id();
            $table->foreignId('workout_session_id')->constrained()->onDelete('cascade');
            $table->foreignId('exercise_id')->constrained()->onDelete('cascade');
            $table->string('status')->default('pending');
            $table->integer('sets_completed')->default(0);
            $table->integer('reps_completed')->default(0);
            $table->timestamps();

            $table->index('workout_session_id');
            $table->index('exercise_id');
        });

        Schema::create('progress_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->date('recorded_at');
            $table->decimal('weight_kg', 5, 1)->nullable();
            $table->decimal('bmi', 5, 2)->nullable();
            $table->integer('workouts_completed')->default(0);
            $table->timestamps();

            $table->index('user_id');
            $table->index('recorded_at');
        });

        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('token');
            $table->string('device_id');
            $table->timestamps();

            $table->index('user_id');
        });
    }
};
