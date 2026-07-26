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
        Schema::create('workout_sessions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('workout_id')->constrained()->onDelete('cascade');
            $table->string('status'); // started, paused, completed
            $table->timestamp('started_at');
            $table->timestamp('completed_at')->nullable();
            $table->integer('total_duration_seconds')->nullable();
            $table->json('pause_log')->nullable();
            $table->timestamps();

            $table->index('user_id');
            $table->index('workout_id');
            $table->index('completed_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('workout_sessions');
    }
};
