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
        Schema::create('workouts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('recommendation_id')->constrained()->onDelete('cascade');
            $table->string('name');
            $table->integer('day_of_week');
            $table->integer('estimated_duration_minutes');
            $table->timestamps();

            $table->index('recommendation_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('workouts');
    }
};
