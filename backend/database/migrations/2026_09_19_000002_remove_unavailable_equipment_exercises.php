<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private const REMOVED_EXERCISES = [
        'Resistance Band Pull-Apart',
        'Kettlebell Press',
        'Kettlebell Goblet Squat',
        'Kettlebell Russian Twist',
        'Kettlebell Swing',
        'Resistance Band Thruster',
        'Resistance Band Lateral Raise',
    ];

    public function up(): void
    {
        DB::table('exercises')->whereIn('name', self::REMOVED_EXERCISES)->delete();
    }

    public function down(): void
    {
        // ExerciseSeeder is the canonical catalog and deliberately no longer
        // contains these client-incompatible exercises.
    }
};
