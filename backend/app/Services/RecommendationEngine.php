<?php

namespace App\Services;

use App\Models\Exercise;
use App\Models\User;
use App\Models\WorkoutSession;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class RecommendationEngine
{
    /**
     * Equipment types available for each workout preference.
     */
    private const EQUIPMENT_BY_PREFERENCE = [
        'home' => ['bodyweight', 'resistance_band', 'kettlebell', 'dumbbell'],
        'gym' => ['bodyweight', 'dumbbell', 'barbell', 'kettlebell', 'resistance_band', 'machine', 'pull_up_bar'],
        'outdoor' => ['bodyweight', 'resistance_band'],
    ];

    /**
     * Rep ranges by fitness goal.
     */
    private const REPS_BY_GOAL = [
        'lose_weight' => ['min' => 12, 'max' => 20],
        'build_muscle' => ['min' => 6, 'max' => 12],
        'stay_fit' => ['min' => 8, 'max' => 15],
        'increase_stamina' => ['min' => 15, 'max' => 20],
    ];

    /**
     * Set ranges by fitness level.
     */
    private const SETS_BY_LEVEL = [
        'beginner' => ['min' => 2, 'max' => 3],
        'intermediate' => ['min' => 3, 'max' => 4],
        'advanced' => ['min' => 4, 'max' => 5],
    ];

    /**
     * Rest periods (in seconds) by fitness goal.
     */
    private const REST_BY_GOAL = [
        'lose_weight' => ['min' => 30, 'max' => 60],
        'build_muscle' => ['min' => 60, 'max' => 120],
        'stay_fit' => ['min' => 45, 'max' => 90],
        'increase_stamina' => ['min' => 30, 'max' => 45],
    ];

    /**
     * Muscle group rotation for 3 days.
     */
    private const ROTATION_3_DAYS = [
        ['chest', 'triceps'],
        ['back', 'biceps'],
        ['legs', 'shoulders'],
    ];

    /**
     * Muscle group rotation for more days (up to 7).
     */
    private const ROTATION_EXTENDED = [
        ['chest'],
        ['back'],
        ['shoulders'],
        ['legs'],
        ['core', 'full_body'],
        ['biceps', 'triceps'],
        ['full_body'],
    ];

    /**
     * Day name to day_of_week number mapping.
     */
    private const DAY_MAP = [
        'monday' => 1,
        'tuesday' => 2,
        'wednesday' => 3,
        'thursday' => 4,
        'friday' => 5,
        'saturday' => 6,
        'sunday' => 7,
    ];

    /**
     * Day name labels for workout naming.
     */
    private const DAY_LABELS = [
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        6 => 'Saturday',
        7 => 'Sunday',
    ];

    /**
     * Generate a personalized weekly workout plan for the user.
     *
     * @param User $user
     * @return array
     */
    public function generate(User $user): array
    {
        $profile = $user->profile;

        $goal = $profile->goal;
        $fitnessLevel = $profile->fitness_level;
        $workoutPreference = $profile->workout_preference;
        $availabilityDays = $profile->availability_days;

        // Get volume parameters
        $repRange = self::REPS_BY_GOAL[$goal] ?? self::REPS_BY_GOAL['stay_fit'];
        $setRange = self::SETS_BY_LEVEL[$fitnessLevel] ?? self::SETS_BY_LEVEL['intermediate'];
        $restRange = self::REST_BY_GOAL[$goal] ?? self::REST_BY_GOAL['stay_fit'];

        // Get adaptation factor based on workout history
        $adaptationFactor = $this->getAdaptationFactor($user);

        // Get allowed equipment
        $allowedEquipment = self::EQUIPMENT_BY_PREFERENCE[$workoutPreference] ?? self::EQUIPMENT_BY_PREFERENCE['gym'];

        // Get difficulty levels to include based on fitness level
        $allowedDifficulties = $this->getAllowedDifficulties($fitnessLevel);

        // Fetch eligible exercises
        $exercises = Exercise::whereIn('equipment', $allowedEquipment)
            ->whereIn('difficulty', $allowedDifficulties)
            ->get();

        // Get muscle group rotation based on number of availability days
        $muscleGroupRotation = $this->getMuscleGroupRotation(count($availabilityDays));

        // Sort availability days by day_of_week number
        $sortedDays = collect($availabilityDays)
            ->map(fn($day) => ['name' => $day, 'number' => self::DAY_MAP[strtolower($day)] ?? 1])
            ->sortBy('number')
            ->values();

        // Build workouts
        $workouts = [];
        foreach ($sortedDays as $index => $dayInfo) {
            $muscleGroups = $muscleGroupRotation[$index % count($muscleGroupRotation)];
            $dayNumber = $dayInfo['number'];
            $dayLabel = self::DAY_LABELS[$dayNumber] ?? 'Day ' . $dayNumber;

            // Create workout name from muscle groups
            $muscleGroupLabel = collect($muscleGroups)
                ->map(fn($mg) => ucfirst(str_replace('_', ' ', $mg)))
                ->implode(' & ');

            $workoutName = $dayLabel . ' - ' . $muscleGroupLabel;

            // Select exercises for this workout
            $workoutExercises = $this->selectExercisesForWorkout(
                $exercises,
                $muscleGroups,
                $goal
            );

            // Assign volume parameters to each exercise with adaptation applied
            $exerciseList = [];
            foreach ($workoutExercises as $order => $exercise) {
                $baseSets = rand($setRange['min'], $setRange['max']);
                $baseReps = rand($repRange['min'], $repRange['max']);
                $restSeconds = rand($restRange['min'], $restRange['max']);

                // Apply adaptation factor to sets and reps
                $sets = $this->applyAdaptation($baseSets, $adaptationFactor, 2, 5);
                $reps = $this->applyAdaptation($baseReps, $adaptationFactor, 5, 20);

                $exerciseList[] = [
                    'exercise_id' => $exercise->id,
                    'sets' => $sets,
                    'reps' => $reps,
                    'rest_seconds' => $restSeconds,
                    'order' => $order + 1,
                ];
            }

            // Calculate estimated duration
            $estimatedDuration = $this->calculateDuration($exerciseList);

            $workouts[] = [
                'name' => $workoutName,
                'day_of_week' => $dayNumber,
                'estimated_duration_minutes' => $estimatedDuration,
                'exercises' => $exerciseList,
            ];
        }

        return [
            'workouts' => $workouts,
        ];
    }

    /**
     * Apply adaptation factor to a base volume value.
     * Rounds to nearest integer and clamps within the given bounds.
     * Ensures at least +1 change when factor > 1.0 and base value allows it.
     */
    private function applyAdaptation(int $baseValue, float $factor, int $min, int $max): int
    {
        if ($factor === 1.0) {
            return $baseValue;
        }

        $adapted = (int) round($baseValue * $factor);

        // Ensure at least +1 change when increasing (if within bounds)
        if ($factor > 1.0 && $adapted <= $baseValue && $baseValue < $max) {
            $adapted = $baseValue + 1;
        }

        // Ensure at least -1 change when decreasing (if within bounds)
        if ($factor < 1.0 && $adapted >= $baseValue && $baseValue > $min) {
            $adapted = $baseValue - 1;
        }

        // Clamp to valid range
        return max($min, min($max, $adapted));
    }

    /**
     * Calculate the adaptation factor based on the user's workout history.
     *
     * Returns:
     *   1.0 for no adaptation (baseline) — user has < 2 weeks of history
     *   1.05 to 1.10 for volume increase — completion rate ≥ 80%
     *   0.90 to 0.95 for volume decrease — skip rate ≥ 50%
     *
     * Completion takes priority if both thresholds would apply.
     */
    public function getAdaptationFactor(User $user): float
    {
        $twoWeeksAgo = Carbon::now()->subDays(14);

        // Get completed workout sessions from the past 14 days
        $recentSessions = WorkoutSession::where('user_id', $user->id)
            ->where('status', 'completed')
            ->where('completed_at', '>=', $twoWeeksAgo)
            ->get();

        // If fewer than 2 completed sessions in the past 14 days, use baseline
        if ($recentSessions->count() < 2) {
            return 1.0;
        }

        // Get all session exercise records for these sessions
        $sessionIds = $recentSessions->pluck('id');
        $sessionExercises = \App\Models\SessionExercise::whereIn('workout_session_id', $sessionIds)->get();

        $totalExercises = $sessionExercises->count();

        // If there are no session exercises, use baseline
        if ($totalExercises === 0) {
            return 1.0;
        }

        $completedCount = $sessionExercises->where('status', 'completed')->count();
        $skippedCount = $sessionExercises->where('status', 'skipped')->count();

        $completionRate = $completedCount / $totalExercises;
        $skipRate = $skippedCount / $totalExercises;

        // Completion takes priority over skip rate
        if ($completionRate >= 0.80) {
            // Increase volume by 5–10% (scale linearly between 80-100% completion)
            $scaleFactor = min(1.0, ($completionRate - 0.80) / 0.20);
            return 1.05 + ($scaleFactor * 0.05); // 1.05 to 1.10
        }

        if ($skipRate >= 0.50) {
            // Decrease volume by 5–10% (scale linearly between 50-100% skip rate)
            $scaleFactor = min(1.0, ($skipRate - 0.50) / 0.50);
            return 0.95 - ($scaleFactor * 0.05); // 0.95 to 0.90
        }

        // No adaptation needed
        return 1.0;
    }

    /**
     * Get allowed difficulty levels based on fitness level.
     * Includes adjacent levels for more variety.
     */
    private function getAllowedDifficulties(string $fitnessLevel): array
    {
        return match ($fitnessLevel) {
            'beginner' => ['beginner', 'intermediate'],
            'intermediate' => ['beginner', 'intermediate', 'advanced'],
            'advanced' => ['intermediate', 'advanced'],
            default => ['beginner', 'intermediate', 'advanced'],
        };
    }

    /**
     * Get muscle group rotation based on the number of available days.
     */
    private function getMuscleGroupRotation(int $numDays): array
    {
        if ($numDays <= 3) {
            return self::ROTATION_3_DAYS;
        }

        // For more days, use the extended rotation
        return array_slice(self::ROTATION_EXTENDED, 0, min($numDays, 7));
    }

    /**
     * Select 4-8 exercises for a workout based on target muscle groups and goal.
     */
    private function selectExercisesForWorkout(
        Collection $allExercises,
        array $muscleGroups,
        string $goal
    ): Collection {
        // Target exercise count based on goal
        $targetCount = $this->getTargetExerciseCount($goal);

        // Filter exercises matching the target muscle groups
        $matchingExercises = $allExercises->filter(
            fn($exercise) => in_array($exercise->muscle_group, $muscleGroups)
        );

        // If not enough matching exercises, include full_body exercises as fillers
        if ($matchingExercises->count() < $targetCount) {
            $fullBodyExercises = $allExercises->filter(
                fn($exercise) => $exercise->muscle_group === 'full_body'
                    && !$matchingExercises->contains('id', $exercise->id)
            );
            $matchingExercises = $matchingExercises->merge($fullBodyExercises);
        }

        // If still not enough, use whatever is available (repeat if necessary)
        if ($matchingExercises->isEmpty()) {
            $matchingExercises = $allExercises->take($targetCount);
        }

        // Shuffle and take the target count
        $selected = $matchingExercises->shuffle()->take($targetCount);

        // If we still don't have enough, repeat exercises to meet minimum of 4
        if ($selected->count() < 4 && $selected->isNotEmpty()) {
            while ($selected->count() < 4) {
                $selected = $selected->merge(
                    $matchingExercises->shuffle()->take(4 - $selected->count())
                );
            }
        }

        return $selected->values();
    }

    /**
     * Get target exercise count based on fitness goal.
     */
    private function getTargetExerciseCount(string $goal): int
    {
        return match ($goal) {
            'lose_weight' => rand(5, 8),
            'build_muscle' => rand(4, 6),
            'stay_fit' => rand(4, 7),
            'increase_stamina' => rand(5, 8),
            default => rand(4, 6),
        };
    }

    /**
     * Calculate estimated workout duration in minutes.
     * Formula: sum of (sets * reps * ~3s per rep + rest between sets) for each exercise.
     */
    private function calculateDuration(array $exercises): int
    {
        $totalSeconds = 0;

        foreach ($exercises as $exercise) {
            $sets = $exercise['sets'];
            $reps = $exercise['reps'];
            $restSeconds = $exercise['rest_seconds'];

            // Estimate ~3 seconds per rep for execution time
            $exerciseTime = $sets * ($reps * 3);
            // Rest between sets (rest applies between sets, so sets - 1 rest periods)
            $restTime = ($sets - 1) * $restSeconds;

            $totalSeconds += $exerciseTime + $restTime;
        }

        // Add transition time between exercises (~30 seconds per transition)
        $totalSeconds += (count($exercises) - 1) * 30;

        return max(1, (int) ceil($totalSeconds / 60));
    }
}
