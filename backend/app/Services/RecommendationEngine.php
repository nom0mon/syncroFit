<?php

namespace App\Services;

use App\Models\Exercise;
use App\Models\User;
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

            // Assign volume parameters to each exercise
            $exerciseList = [];
            foreach ($workoutExercises as $order => $exercise) {
                $sets = rand($setRange['min'], $setRange['max']);
                $reps = rand($repRange['min'], $repRange['max']);
                $restSeconds = rand($restRange['min'], $restRange['max']);

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
