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
        $this->assertSame(31, Exercise::count());
        Exercise::all()->each(function (Exercise $exercise): void {
            $this->assertNotEmpty($exercise->environments, $exercise->name);
            $this->assertSame('catalog_cross_checked', $exercise->verification_status, $exercise->name);
            $this->assertSame('https://github.com/yuhonas/free-exercise-db', $exercise->source_reference);
        });
    }

    public function test_environment_portable_exercises_span_all_locations_while_equipment_dependent_stay_gym(): void
    {
        $this->seed(ExerciseSeeder::class);

        // Bodyweight and pull-up-bar movements are environment-portable: they
        // are eligible at home, gym, and outdoor (see categorized_exercises_revised.md).
        foreach (['Pike Push-Up', 'Walking Lunge', 'Pull-Up'] as $name) {
            $environments = Exercise::where('name', $name)->firstOrFail()->environments;
            $this->assertContains('home', $environments, $name);
            $this->assertContains('gym', $environments, $name);
            $this->assertContains('outdoor', $environments, $name);
        }

        // Equipment-dependent movements stay gym-only.
        $dumbbell = Exercise::where('name', 'Dumbbell Bicep Curl')->firstOrFail()->environments;
        $this->assertContains('gym', $dumbbell);
        $this->assertNotContains('home', $dumbbell);
        $this->assertNotContains('outdoor', $dumbbell);
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

    public function test_outdoor_plan_uses_only_environment_portable_equipment(): void
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

        $this->assertNotEmpty($exerciseIds);
        // Outdoor plans assume a bar is available, so bodyweight and pull-up-bar
        // movements are eligible; portable or fixed gym equipment never is.
        Exercise::whereIn('id', $exerciseIds)->get()->each(function (Exercise $exercise): void {
            $this->assertContains($exercise->equipment, ['bodyweight', 'pull_up_bar'], $exercise->name);
        });
    }

    public function test_home_plan_uses_only_environment_portable_equipment(): void
    {
        $this->seed(ExerciseSeeder::class);
        $user = User::factory()->create();
        $user->profile()->create([
            'age' => 25, 'height_cm' => 175, 'weight_kg' => 70,
            'gender' => 'prefer_not_to_say', 'goal' => 'stay_fit',
            'fitness_level' => 'intermediate', 'workout_preference' => 'home',
            'availability_days' => ['monday'],
        ]);

        $result = app(RecommendationEngine::class)->generate($user->load('profile'));
        $ids = collect($result['workouts'])->pluck('exercises')->flatten(1)->pluck('exercise_id');

        $this->assertNotEmpty($ids);
        // Home plans assume a bar is available, so bodyweight and pull-up-bar
        // movements are eligible; other equipment never is.
        Exercise::whereIn('id', $ids)->get()->each(function (Exercise $exercise): void {
            $this->assertContains($exercise->equipment, ['bodyweight', 'pull_up_bar'], $exercise->name);
        });
    }

    public function test_home_and_outdoor_fill_every_available_day_without_same_session_duplicates(): void
    {
        $this->seed(ExerciseSeeder::class);
        $availableDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

        foreach (['home', 'outdoor'] as $environment) {
            foreach (range(1, 6) as $dayCount) {
                $user = User::factory()->create();
                $user->profile()->create([
                    'age' => 25,
                    'height_cm' => 175,
                    'weight_kg' => 70,
                    'gender' => 'prefer_not_to_say',
                    'goal' => 'stay_fit',
                    'fitness_level' => 'intermediate',
                    'workout_preference' => $environment,
                    'availability_days' => array_slice($availableDays, 0, $dayCount),
                ]);

                $result = app(RecommendationEngine::class)->generate($user->load('profile'));

                $this->assertCount($dayCount, $result['workouts'], "{$environment} {$dayCount}-day plan");
                foreach ($result['workouts'] as $workout) {
                    $exerciseIds = collect($workout['exercises'])->pluck('exercise_id');
                    $this->assertNotEmpty($exerciseIds, "{$environment} day {$workout['day_of_week']}");
                    $this->assertSame(
                        $exerciseIds->count(),
                        $exerciseIds->unique()->count(),
                        "{$environment} day {$workout['day_of_week']} contains a duplicate exercise"
                    );
                }
            }
        }
    }
}
