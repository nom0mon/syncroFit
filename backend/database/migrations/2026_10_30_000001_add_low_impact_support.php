<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Adds low-impact personalization.
 *
 *  - profiles.low_impact_only: member preference/need to avoid high-impact work.
 *  - exercises.impact_level: low | moderate | high joint-impact classification.
 *
 * "Impact" describes joint loading (jumping/explosive ground contact), not
 * training intensity; fitness_level already controls intensity.
 *
 * New exercises default to 'moderate' so an untagged movement is never
 * treated as low-impact by accident.
 */
return new class extends Migration
{
    private const HIGH_IMPACT = ['Burpee', 'Jumping Jack', 'High Knees', 'Broad Jump'];

    private const MODERATE_IMPACT = ['Dumbbell Clean and Press'];

    public function up(): void
    {
        Schema::table('profiles', function (Blueprint $table) {
            $table->boolean('low_impact_only')->default(false)->after('workout_preference');
        });

        Schema::table('exercises', function (Blueprint $table) {
            $table->string('impact_level')->default('moderate')->after('exercise_type');
        });

        // Everything is low-impact unless explicitly classified otherwise.
        DB::table('exercises')->update(['impact_level' => 'low']);
        DB::table('exercises')->whereIn('name', self::MODERATE_IMPACT)->update(['impact_level' => 'moderate']);
        DB::table('exercises')->whereIn('name', self::HIGH_IMPACT)->update(['impact_level' => 'high']);
    }

    public function down(): void
    {
        Schema::table('exercises', function (Blueprint $table) {
            $table->dropColumn('impact_level');
        });

        Schema::table('profiles', function (Blueprint $table) {
            $table->dropColumn('low_impact_only');
        });
    }
};
