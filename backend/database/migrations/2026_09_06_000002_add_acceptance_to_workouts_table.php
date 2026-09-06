<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('workouts', function (Blueprint $table) {
            $table->uuid('plan_id')->nullable()->after('user_id')->index();
            $table->boolean('is_accepted')->default(true)->after('is_generated')->index();
            $table->timestamp('accepted_at')->nullable()->after('is_accepted');
        });
    }

    public function down(): void
    {
        Schema::table('workouts', function (Blueprint $table) {
            $table->dropIndex(['plan_id']);
            $table->dropIndex(['is_accepted']);
            $table->dropColumn(['plan_id', 'is_accepted', 'accepted_at']);
        });
    }
};
