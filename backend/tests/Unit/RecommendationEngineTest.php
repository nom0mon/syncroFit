<?php

namespace Tests\Unit;

use App\Models\Exercise;
use App\Models\Profile;
use App\Models\User;
use App\Services\RecommendationEngine;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RecommendationEngineTest extends TestCase
{
    use RefreshDatabase;

    private RecommendationEngine $engine;

    protected function setUp(): void
    {
        parent::setUp();
        $this->engine = new RecommendationEngine();
        $this->seedExercises();
    }

    public function test_generates_one_workout_per_availability_day(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        $result = $this->engine->generate($user);

        $this->assertArrayHasKey('workouts', $result);
        $this->assertCount(3, $result['workouts']);
    }

    public function test_each_workout_has_4_to_8_exercises(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'tuesday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            $this->assertGreaterThanOrEqual(4, count($workout['exercises']));
            $this->assertLessThanOrEqual(8, count($workout['exercises']));
        }
    }

    public function test_sets_within_range_for_beginner(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'beginner',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertGreaterThanOrEqual(2, $exercise['sets']);
                $this->assertLessThanOrEqual(3, $exercise['sets']);
            }
        }
    }

    public function test_sets_within_range_for_intermediate(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertGreaterThanOrEqual(3, $exercise['sets']);
                $this->assertLessThanOrEqual(4, $exercise['sets']);
            }
        }
    }

    public function test_sets_within_range_for_advanced(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'advanced',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertGreaterThanOrEqual(4, $exercise['sets']);
                $this->assertLessThanOrEqual(5, $exercise['sets']);
            }
        }
    }

    public function test_reps_within_range_for_lose_weight(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'lose_weight',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertGreaterThanOrEqual(12, $exercise['reps']);
                $this->assertLessThanOrEqual(20, $exercise['reps']);
            }
        }
    }

    public function test_reps_within_range_for_build_muscle(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertGreaterThanOrEqual(6, $exercise['reps']);
                $this->assertLessThanOrEqual(12, $exercise['reps']);
            }
        }
    }

    public function test_reps_within_range_for_increase_stamina(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'increase_stamina',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertGreaterThanOrEqual(15, $exercise['reps']);
                $this->assertLessThanOrEqual(20, $exercise['reps']);
            }
        }
    }

    public function test_rest_within_range_for_build_muscle(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertGreaterThanOrEqual(60, $exercise['rest_seconds']);
                $this->assertLessThanOrEqual(120, $exercise['rest_seconds']);
            }
        }
    }

    public function test_rest_within_range_for_lose_weight(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'lose_weight',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exercise) {
                $this->assertGreaterThanOrEqual(30, $exercise['rest_seconds']);
                $this->assertLessThanOrEqual(60, $exercise['rest_seconds']);
            }
        }
    }

    public function test_workout_day_of_week_matches_availability(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['tuesday', 'thursday', 'saturday'],
        ]);

        $result = $this->engine->generate($user);

        $dayNumbers = array_column($result['workouts'], 'day_of_week');
        $this->assertContains(2, $dayNumbers); // Tuesday
        $this->assertContains(4, $dayNumbers); // Thursday
        $this->assertContains(6, $dayNumbers); // Saturday
    }

    public function test_home_preference_uses_only_home_equipment(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'beginner',
            'workout_preference' => 'home',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        $result = $this->engine->generate($user);

        $allowedEquipment = ['bodyweight', 'resistance_band', 'kettlebell', 'dumbbell'];

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exerciseData) {
                $exercise = Exercise::find($exerciseData['exercise_id']);
                $this->assertContains(
                    $exercise->equipment,
                    $allowedEquipment,
                    "Exercise '{$exercise->name}' uses '{$exercise->equipment}' which is not available for home workouts"
                );
            }
        }
    }

    public function test_outdoor_preference_uses_only_outdoor_equipment(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'beginner',
            'workout_preference' => 'outdoor',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        $result = $this->engine->generate($user);

        $allowedEquipment = ['bodyweight', 'resistance_band'];

        foreach ($result['workouts'] as $workout) {
            foreach ($workout['exercises'] as $exerciseData) {
                $exercise = Exercise::find($exerciseData['exercise_id']);
                $this->assertContains(
                    $exercise->equipment,
                    $allowedEquipment,
                    "Exercise '{$exercise->name}' uses '{$exercise->equipment}' which is not available for outdoor workouts"
                );
            }
        }
    }

    public function test_workout_has_valid_structure(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'advanced',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            $this->assertArrayHasKey('name', $workout);
            $this->assertArrayHasKey('day_of_week', $workout);
            $this->assertArrayHasKey('estimated_duration_minutes', $workout);
            $this->assertArrayHasKey('exercises', $workout);
            $this->assertIsString($workout['name']);
            $this->assertIsInt($workout['day_of_week']);
            $this->assertIsInt($workout['estimated_duration_minutes']);
            $this->assertGreaterThan(0, $workout['estimated_duration_minutes']);

            foreach ($workout['exercises'] as $exercise) {
                $this->assertArrayHasKey('exercise_id', $exercise);
                $this->assertArrayHasKey('sets', $exercise);
                $this->assertArrayHasKey('reps', $exercise);
                $this->assertArrayHasKey('rest_seconds', $exercise);
                $this->assertArrayHasKey('order', $exercise);
            }
        }
    }

    public function test_exercises_have_sequential_order(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday'],
        ]);

        $result = $this->engine->generate($user);

        foreach ($result['workouts'] as $workout) {
            $orders = array_column($workout['exercises'], 'order');
            $expected = range(1, count($workout['exercises']));
            $this->assertEquals($expected, $orders);
        }
    }

    public function test_generates_for_single_availability_day(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'beginner',
            'workout_preference' => 'gym',
            'availability_days' => ['wednesday'],
        ]);

        $result = $this->engine->generate($user);

        $this->assertCount(1, $result['workouts']);
        $this->assertEquals(3, $result['workouts'][0]['day_of_week']);
    }

    public function test_generates_for_seven_availability_days(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'stay_fit',
            'fitness_level' => 'advanced',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
        ]);

        $result = $this->engine->generate($user);

        $this->assertCount(7, $result['workouts']);
    }

    /**
     * Create a user with a profile.
     */
    private function createUserWithProfile(array $profileData): User
    {
        $user = User::factory()->create();

        $defaults = [
            'user_id' => $user->id,
            'age' => 25,
            'height_cm' => 175,
            'weight_kg' => 70,
            'gender' => 'male',
            'goal' => 'stay_fit',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
            'bmi' => 22.86,
        ];

        Profile::create(array_merge($defaults, $profileData));

        // Reload user with profile relation
        return $user->fresh(['profile']);
    }

    /**
     * Seed exercises into the database for testing.
     */
    private function seedExercises(): void
    {
        $this->artisan('db:seed', ['--class' => 'Database\\Seeders\\ExerciseSeeder']);
    }
}
