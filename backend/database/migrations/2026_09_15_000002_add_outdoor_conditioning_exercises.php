<?php

use Database\Seeders\ExerciseSeeder;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
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
