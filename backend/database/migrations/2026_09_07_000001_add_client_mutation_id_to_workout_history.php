<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('workout_history', function (Blueprint $table) {
            $table->string('client_mutation_id', 100)->nullable()->after('user_id');
            $table->unique(['user_id', 'client_mutation_id']);
        });
    }

    public function down(): void
    {
        Schema::table('workout_history', function (Blueprint $table) {
            $table->dropUnique(['user_id', 'client_mutation_id']);
            $table->dropColumn('client_mutation_id');
        });
    }
};
