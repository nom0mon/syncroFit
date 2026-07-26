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
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('workout_exercises');
    }
};
