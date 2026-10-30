<?php

use Database\Seeders\ExerciseSeeder;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Ensure impact_level column exists before running the seeder, since
        // the seeder writes impact_level and the column may not yet exist on
        // older development databases being upgraded incrementally.
        if (!Schema::hasColumn('exercises', 'impact_level')) {
            Schema::table('exercises', function (Blueprint $table) {
                $table->string('impact_level')->default('low')->after('exercise_type');
            });
        }

        // Upgrade an existing deployed catalog in place. On a fresh database,
        // DatabaseSeeder remains responsible for populating exercises; seeding
        // inside a migration would pollute isolated tests that use factories.
        if (DB::table('exercises')->exists()) {
            (new ExerciseSeeder())->run();
        }

        $outdoor = ['Walking Lunge', 'Mountain Climber', 'Jumping Jack', 'High Knees', 'Broad Jump'];
        DB::table('exercises')->whereIn('name', $outdoor)
            ->update(['environments' => json_encode(['gym', 'outdoor'])]);

        DB::table('exercises')->where('equipment', 'bodyweight')
            ->whereNotIn('name', array_merge($outdoor, ['Push-Up', 'Bodyweight Squat', 'Plank', 'Burpee']))
            ->update(['environments' => json_encode(['home', 'gym'])]);

        DB::table('exercises')->whereIn('name', ['Push-Up', 'Bodyweight Squat', 'Plank', 'Burpee'])
            ->update(['environments' => json_encode(['home', 'gym', 'outdoor'])]);
    }

    public function down(): void
    {
        DB::table('exercises')->whereIn('name', [
            'Walking Lunge', 'Mountain Climber', 'Jumping Jack', 'High Knees', 'Broad Jump',
        ])->delete();
    }
};
