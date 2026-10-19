<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private const REMOVED_EXERCISES = [
        // The gym environment has no resistance bands, so the sole
        // resistance-band exercise is removed from the catalog.
        'Resistance Band Curl',
    ];

    public function up(): void
    {
        DB::table('exercises')->whereIn('name', self::REMOVED_EXERCISES)->delete();
    }

    public function down(): void
    {
        // ExerciseSeeder is the canonical catalog and deliberately no longer
        // contains this exercise.
    }
};
