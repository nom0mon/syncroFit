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
        Schema::create('profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->integer('age');
            $table->decimal('height_cm', 5, 1);
            $table->decimal('weight_kg', 5, 1);
            $table->string('gender'); // male, female, other
            $table->string('goal'); // lose_weight, build_muscle, stay_fit, increase_stamina
            $table->string('fitness_level'); // beginner, intermediate, advanced
            $table->string('workout_preference'); // home, gym, outdoor
            $table->json('availability_days');
            $table->decimal('bmi', 5, 2)->nullable();
            $table->timestamps();

            $table->index('user_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('profiles');
    }
};
