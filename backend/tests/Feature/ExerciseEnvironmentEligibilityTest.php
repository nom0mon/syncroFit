<?php

namespace Tests\Feature;

use App\Models\Exercise;
use App\Models\User;
use App\Services\RecommendationEngine;
use Database\Seeders\ExerciseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExerciseEnvironmentEligibilityTest extends TestCase
{
    use RefreshDatabase;

    public function test_seeded_catalog_has_valid_source_and_environment_metadata(): void
    {
        $this->seed(ExerciseSeeder::class);
        $manifest = json_decode(file_get_contents(database_path('data/exercise_catalog_manifest.json')), true, flags: JSON_THROW_ON_ERROR);
        $policy = $manifest['environment_policy'];

        $this->assertSame(34, Exercise::count());
        Exercise::all()->each(function (Exercise $exercise) use ($policy): void {
            $this->assertSame($policy[$exercise->equipment], $exercise->environments, $exercise->name);
            $this->assertSame('catalog_cross_checked', $exercise->verification_status, $exercise->name);
            $this->assertSame('https://github.com/yuhonas/free-exercise-db', $exercise->source_reference);
        });
    }

    public function test_each_environment_only_receives_exercises_classified_for_it(): void
    {
        $this->seed(ExerciseSeeder::class);

        foreach (['home', 'gym', 'outdoor'] as $environment) {
            $user = User::factory()->create();
            $user->profile()->create([
                'age' => 25,
                'height_cm' => 175,
                'weight_kg' => 70,
                'gender' => 'prefer_not_to_say',
                'goal' => 'stay_fit',
                'fitness_level' => 'intermediate',
                'workout_preference' => $environment,
                'availability_days' => ['monday'],
            ]);

            $result = app(RecommendationEngine::class)->generate($user->load('profile'));
            $exerciseIds = collect($result['workouts'])->pluck('exercises')->flatten(1)->pluck('exercise_id');

            $this->assertNotEmpty($exerciseIds, $environment);
            Exercise::whereIn('id', $exerciseIds)->get()->each(
                fn (Exercise $exercise) => $this->assertContains($environment, $exercise->environments, $exercise->name)
            );
        }
    }

    public function test_outdoor_plan_does_not_assume_portable_or_fixed_equipment(): void
    {
        $this->seed(ExerciseSeeder::class);
        $user = User::factory()->create();
        $user->profile()->create([
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'prefer_not_to_say',
            'goal' => 'stay_fit',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'outdoor',
            'availability_days' => ['monday'],
        ]);

        $result = app(RecommendationEngine::class)->generate($user->load('profile'));
        $exerciseIds = collect($result['workouts'])->pluck('exercises')->flatten(1)->pluck('exercise_id');

        $this->assertSame(['bodyweight'], Exercise::whereIn('id', $exerciseIds)->pluck('equipment')->unique()->values()->all());
    }
}
