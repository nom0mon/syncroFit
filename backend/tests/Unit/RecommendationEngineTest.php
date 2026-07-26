<?php

namespace Tests\Unit;

use App\Models\Exercise;
use App\Models\Profile;
use App\Models\Recommendation;
use App\Models\SessionExercise;
use App\Models\User;
use App\Models\Workout;
use App\Models\WorkoutSession;
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

    // ===== Adaptation Logic Tests =====

    public function test_adaptation_returns_baseline_with_no_history(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        // No workout sessions created — user has no history
        $factor = $this->engine->getAdaptationFactor($user);

        $this->assertEquals(1.0, $factor);
    }

    public function test_adaptation_returns_baseline_with_only_one_completed_session(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        // Create only 1 completed session (need ≥2 for adaptation)
        $workout = $this->createWorkoutForUser($user);
        $session = $this->createCompletedSession($user, $workout, now()->subDays(3));
        $exercise = Exercise::first();
        SessionExercise::create([
            'workout_session_id' => $session->id,
            'exercise_id' => $exercise->id,
            'status' => 'completed',
            'sets_completed' => 3,
            'reps_completed' => 10,
        ]);

        $factor = $this->engine->getAdaptationFactor($user);

        $this->assertEquals(1.0, $factor);
    }

    public function test_adaptation_increases_volume_with_high_completion(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        $workout = $this->createWorkoutForUser($user);
        $exercise = Exercise::first();

        // Create 3 completed sessions where ≥80% of exercises are 'completed'
        for ($i = 1; $i <= 3; $i++) {
            $session = $this->createCompletedSession($user, $workout, now()->subDays($i * 2));

            // 5 exercises: 4 completed (80%) + 1 pending
            for ($j = 0; $j < 4; $j++) {
                SessionExercise::create([
                    'workout_session_id' => $session->id,
                    'exercise_id' => $exercise->id,
                    'status' => 'completed',
                    'sets_completed' => 3,
                    'reps_completed' => 10,
                ]);
            }
            SessionExercise::create([
                'workout_session_id' => $session->id,
                'exercise_id' => $exercise->id,
                'status' => 'pending',
                'sets_completed' => 0,
                'reps_completed' => 0,
            ]);
        }

        $factor = $this->engine->getAdaptationFactor($user);

        $this->assertGreaterThanOrEqual(1.05, $factor);
        $this->assertLessThanOrEqual(1.10, $factor);
    }

    public function test_adaptation_decreases_volume_with_high_skip_rate(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        $workout = $this->createWorkoutForUser($user);
        $exercise = Exercise::first();

        // Create 3 completed sessions where ≥50% of exercises are 'skipped'
        for ($i = 1; $i <= 3; $i++) {
            $session = $this->createCompletedSession($user, $workout, now()->subDays($i * 2));

            // 4 exercises: 2 skipped (50%) + 2 completed (50%)
            for ($j = 0; $j < 2; $j++) {
                SessionExercise::create([
                    'workout_session_id' => $session->id,
                    'exercise_id' => $exercise->id,
                    'status' => 'skipped',
                    'sets_completed' => 0,
                    'reps_completed' => 0,
                ]);
            }
            for ($j = 0; $j < 2; $j++) {
                SessionExercise::create([
                    'workout_session_id' => $session->id,
                    'exercise_id' => $exercise->id,
                    'status' => 'completed',
                    'sets_completed' => 3,
                    'reps_completed' => 10,
                ]);
            }
        }

        $factor = $this->engine->getAdaptationFactor($user);

        $this->assertGreaterThanOrEqual(0.90, $factor);
        $this->assertLessThanOrEqual(0.95, $factor);
    }

    public function test_adaptation_returns_baseline_when_neither_threshold_met(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        $workout = $this->createWorkoutForUser($user);
        $exercise = Exercise::first();

        // Create 3 completed sessions where completion < 80% AND skip < 50%
        for ($i = 1; $i <= 3; $i++) {
            $session = $this->createCompletedSession($user, $workout, now()->subDays($i * 2));

            // 5 exercises: 3 completed (60%), 1 skipped (20%), 1 pending (20%)
            for ($j = 0; $j < 3; $j++) {
                SessionExercise::create([
                    'workout_session_id' => $session->id,
                    'exercise_id' => $exercise->id,
                    'status' => 'completed',
                    'sets_completed' => 3,
                    'reps_completed' => 10,
                ]);
            }
            SessionExercise::create([
                'workout_session_id' => $session->id,
                'exercise_id' => $exercise->id,
                'status' => 'skipped',
                'sets_completed' => 0,
                'reps_completed' => 0,
            ]);
            SessionExercise::create([
                'workout_session_id' => $session->id,
                'exercise_id' => $exercise->id,
                'status' => 'pending',
                'sets_completed' => 0,
                'reps_completed' => 0,
            ]);
        }

        $factor = $this->engine->getAdaptationFactor($user);

        $this->assertEquals(1.0, $factor);
    }

    public function test_adaptation_completion_takes_priority_over_skip(): void
    {
        $user = $this->createUserWithProfile([
            'goal' => 'build_muscle',
            'fitness_level' => 'intermediate',
            'workout_preference' => 'gym',
            'availability_days' => ['monday', 'wednesday', 'friday'],
        ]);

        $workout = $this->createWorkoutForUser($user);
        $exercise = Exercise::first();

        // Create 3 sessions where completion ≥80% — the high completion rate
        // means the skip condition is irrelevant (completion takes priority)
        for ($i = 1; $i <= 3; $i++) {
            $session = $this->createCompletedSession($user, $workout, now()->subDays($i * 2));

            // 5 exercises: 5 completed (100% completion)
            for ($j = 0; $j < 5; $j++) {
                SessionExercise::create([
                    'workout_session_id' => $session->id,
                    'exercise_id' => $exercise->id,
                    'status' => 'completed',
                    'sets_completed' => 3,
                    'reps_completed' => 10,
                ]);
            }
        }

        $factor = $this->engine->getAdaptationFactor($user);

        // Factor should be > 1.0 (increase) because completion takes priority
        $this->assertGreaterThan(1.0, $factor);
        $this->assertGreaterThanOrEqual(1.05, $factor);
        $this->assertLessThanOrEqual(1.10, $factor);
    }

    public function test_all_goal_level_combinations_generate_valid_plans(): void
    {
        $goals = ['lose_weight', 'build_muscle', 'stay_fit', 'increase_stamina'];
        $levels = ['beginner', 'intermediate', 'advanced'];

        foreach ($goals as $goal) {
            foreach ($levels as $level) {
                $user = $this->createUserWithProfile([
                    'goal' => $goal,
                    'fitness_level' => $level,
                    'workout_preference' => 'gym',
                    'availability_days' => ['monday', 'wednesday', 'friday'],
                ]);

                $result = $this->engine->generate($user);

                $this->assertArrayHasKey('workouts', $result, "Missing 'workouts' key for goal=$goal, level=$level");
                $this->assertCount(3, $result['workouts'], "Expected 3 workouts for goal=$goal, level=$level");

                foreach ($result['workouts'] as $workout) {
                    $exerciseCount = count($workout['exercises']);
                    $this->assertGreaterThanOrEqual(4, $exerciseCount, "Too few exercises for goal=$goal, level=$level");
                    $this->assertLessThanOrEqual(8, $exerciseCount, "Too many exercises for goal=$goal, level=$level");

                    foreach ($workout['exercises'] as $exercise) {
                        $this->assertGreaterThanOrEqual(2, $exercise['sets'], "Sets too low for goal=$goal, level=$level");
                        $this->assertLessThanOrEqual(5, $exercise['sets'], "Sets too high for goal=$goal, level=$level");
                        $this->assertGreaterThanOrEqual(5, $exercise['reps'], "Reps too low for goal=$goal, level=$level");
                        $this->assertLessThanOrEqual(20, $exercise['reps'], "Reps too high for goal=$goal, level=$level");
                        $this->assertGreaterThanOrEqual(30, $exercise['rest_seconds'], "Rest too low for goal=$goal, level=$level");
                        $this->assertLessThanOrEqual(120, $exercise['rest_seconds'], "Rest too high for goal=$goal, level=$level");
                    }
                }
            }
        }
    }

    // ===== Helper Methods for Adaptation Tests =====

    /**
     * Create a Workout record linked to the user (via Recommendation).
     */
    private function createWorkoutForUser(User $user): Workout
    {
        $recommendation = Recommendation::create([
            'user_id' => $user->id,
            'week_start' => now()->startOfWeek()->toDateString(),
            'plan_data' => [],
        ]);

        return Workout::create([
            'recommendation_id' => $recommendation->id,
            'name' => 'Test Workout',
            'day_of_week' => 1,
            'estimated_duration_minutes' => 45,
        ]);
    }

    /**
     * Create a completed WorkoutSession record within the past 14 days.
     */
    private function createCompletedSession(User $user, Workout $workout, $completedAt): WorkoutSession
    {
        return WorkoutSession::create([
            'user_id' => $user->id,
            'workout_id' => $workout->id,
            'status' => 'completed',
            'started_at' => $completedAt->copy()->subHour(),
            'completed_at' => $completedAt,
            'total_duration_seconds' => 3600,
            'pause_log' => [],
        ]);
    }

    /**
     * Seed exercises into the database for testing.
     */
    private function seedExercises(): void
    {
        $this->artisan('db:seed', ['--class' => 'Database\\Seeders\\ExerciseSeeder']);
    }
}
