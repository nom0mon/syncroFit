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
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('progress_records');
    }
};
