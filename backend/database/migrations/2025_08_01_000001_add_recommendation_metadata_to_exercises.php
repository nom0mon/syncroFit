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
        Schema::table('exercises', function (Blueprint $table) {
            // knee_dominant, hip_dominant, horizontal_push, horizontal_pull,
            // vertical_push, vertical_pull, core, accessory, full_body
            $table->string('movement_pattern')->nullable();
            $table->json('primary_muscles')->nullable();
            $table->json('secondary_muscles')->nullable();
            $table->string('exercise_type')->nullable(); // compound, isolation
            // muscle_gain, strength, general_fitness, fat_loss, endurance
            $table->json('goals')->nullable();

            $table->index('movement_pattern');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('exercises', function (Blueprint $table) {
            $table->dropIndex(['movement_pattern']);
            $table->dropColumn([
                'movement_pattern',
                'primary_muscles',
                'secondary_muscles',
                'exercise_type',
                'goals',
            ]);
        });
    }
};
