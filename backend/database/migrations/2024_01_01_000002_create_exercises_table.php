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
        Schema::create('exercises', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description');
            $table->json('instructions');
            $table->string('muscle_group'); // chest, back, shoulders, biceps, triceps, legs, core, full_body
            $table->string('equipment');
            $table->string('difficulty'); // beginner, intermediate, advanced
            $table->integer('default_sets');
            $table->integer('default_reps');
            $table->integer('default_duration_seconds');
            $table->string('image_url')->nullable();
            $table->timestamps();

            $table->index('muscle_group');
            $table->index('difficulty');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('exercises');
    }
};
