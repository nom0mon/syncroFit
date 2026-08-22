<?php

namespace App\Services;

use App\Models\Exercise;
use App\Models\User;
use App\Models\WorkoutHistory;
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
     * Profile goal -> engine goal mapping used for scoring.
     */
    private const GOAL_MAP = [
        'lose_weight' => 'fat_loss',
        'build_muscle' => 'muscle_gain',
        'stay_fit' => 'general_fitness',
        'increase_stamina' => 'endurance',
    ];

    /**
     * Day name to day_of_week number mapping (1=Monday .. 7=Sunday).
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
     * Human-readable labels for each machine workout type key.
     */
    private const WORKOUT_TYPE_LABELS = [
        'full_body' => 'Full Body',
        'full_body_a' => 'Full Body A',
        'full_body_b' => 'Full Body B',
        'full_body_c' => 'Full Body C',
        'upper_a' => 'Upper A',
        'upper_b' => 'Upper B',
        'lower_a' => 'Lower A',
        'lower_b' => 'Lower B',
        'push_a' => 'Push A',
        'push_b' => 'Push B',
        'pull_a' => 'Pull A',
        'pull_b' => 'Pull B',
        'legs_a' => 'Legs A',
        'legs_b' => 'Legs B',
    ];

    /**
     * Required weekly muscle coverage targets.
     */
    private const REQUIRED_MUSCLES = [
        'chest', 'back', 'shoulders', 'biceps', 'triceps',
        'quadriceps', 'hamstrings', 'glutes', 'core',
    ];

    /**
     * Generate a personalized weekly workout plan for the user.
     *
     * @param  User  $user
     * @param  int[]  $includedExerciseIds  Exercise IDs to strongly favor.
     * @param  int[]  $excludedExerciseIds  Exercise IDs to never include.
     * @return array{workouts: array<int, array>, meta: array{coverage: array<string, float>, unresolved_slots: array}}
     */
    public function generate(User $user, array $includedExerciseIds = [], array $excludedExerciseIds = []): array
    {
        $profile = $user->profile;

        $goal = $profile->goal;
        $fitnessLevel = $profile->fitness_level;
        $workoutPreference = $profile->workout_preference;
        $availabilityDays = $profile->availability_days ?? [];

        $includedExerciseIds = array_map('intval', $includedExerciseIds);
        $excludedExerciseIds = array_map('intval', $excludedExerciseIds);

        $allowedEquipment = self::EQUIPMENT_BY_PREFERENCE[$workoutPreference] ?? self::EQUIPMENT_BY_PREFERENCE['gym'];
        $allowedDifficulties = $this->getAllowedDifficulties($fitnessLevel);
        $mappedGoal = self::GOAL_MAP[$goal] ?? 'general_fitness';

        // Sort available days Monday -> Sunday and cap generated workout count.
        $sortedDays = collect($availabilityDays)
            ->map(fn ($day) => self::DAY_MAP[strtolower((string) $day)] ?? null)
            ->filter()
            ->unique()
            ->sort()
            ->values();

        $numDays = $sortedDays->count();
        $split = $this->determineSplit($numDays);

        // If 7 days chosen the split caps at 6 (7th is recovery); zip only the
        // first count($split) sorted days.
        $split = array_slice($split, 0, min(count($split), $numDays));

        $adaptationFactor = $this->getAdaptationFactor($user);

        // IDs used so far this week for the variety rule.
        $usedExerciseIds = [];
        $workouts = [];
        $unresolvedSlots = [];

        foreach ($split as $index => $workoutType) {
            $dayNumber = (int) $sortedDays[$index];
            $slots = $this->slotsForWorkoutType($workoutType);

            $selectedExercises = [];
            foreach ($slots as $slotIndex => $slot) {
                $candidate = $this->selectExerciseForSlot(
                    $slot,
                    $allowedEquipment,
                    $allowedDifficulties,
                    $mappedGoal,
                    $usedExerciseIds,
                    $includedExerciseIds,
                    $excludedExerciseIds
                );

                if ($candidate === null) {
                    $unresolvedSlots[] = [
                        'workout_type' => $workoutType,
                        'day_of_week' => $dayNumber,
                        'slot_index' => $slotIndex,
                        'patterns' => $slot['patterns'],
                    ];
                    continue;
                }

                $usedExerciseIds[] = $candidate->id;
                $selectedExercises[] = $candidate;
            }

            $exerciseList = $this->buildExerciseList($selectedExercises, $goal, $fitnessLevel, $adaptationFactor);
            $estimatedDuration = $this->calculateDuration($exerciseList);

            $workouts[] = [
                'name' => self::WORKOUT_TYPE_LABELS[$workoutType] ?? ucwords(str_replace('_', ' ', $workoutType)),
                'workout_type' => $workoutType,
                'day_of_week' => $dayNumber,
                'estimated_duration_minutes' => $estimatedDuration,
                'exercises' => $exerciseList,
                // Keep the exercise models around for coverage validation.
                '_selected' => $selectedExercises,
            ];
        }

        // Muscle coverage validation + best-effort remediation.
        $this->ensureMuscleCoverage(
            $workouts,
            $usedExerciseIds,
            $allowedEquipment,
            $allowedDifficulties,
            $mappedGoal,
            $goal,
            $fitnessLevel,
            $adaptationFactor,
            $excludedExerciseIds,
            $includedExerciseIds
        );

        $coverage = $this->computeCoverage($workouts);

        // Strip internal helper key from the public payload.
        $workouts = array_map(function (array $workout): array {
            unset($workout['_selected']);
            return $workout;
        }, $workouts);

        return [
            'workouts' => array_values($workouts),
            'meta' => [
                'coverage' => $coverage,
                'unresolved_slots' => $unresolvedSlots,
            ],
        ];
    }

    /**
     * Determine the workout split from the number of available days.
     *
     * @return string[] machine keys for each workout in order
     */
    private function determineSplit(int $numDays): array
    {
        return match (true) {
            $numDays <= 1 => ['full_body'],
            $numDays === 2 => ['full_body_a', 'full_body_b'],
            $numDays === 3 => ['full_body_a', 'full_body_b', 'full_body_c'],
            $numDays === 4 => ['upper_a', 'lower_a', 'upper_b', 'lower_b'],
            $numDays === 5 => ['upper_a', 'lower_a', 'full_body', 'upper_b', 'lower_b'],
            // 6 or more days (cap at 6). If 7 days selected the 7th is recovery.
            default => ['push_a', 'pull_a', 'legs_a', 'push_b', 'pull_b', 'legs_b'],
        };
    }

    /**
     * Required movement-pattern slots for a workout type.
     *
     * Each slot is ['patterns' => [...], 'label' => ...]. When more than one
     * pattern is listed the earlier pools are tried first ("X OR Y").
     *
     * @return array<int, array{patterns: string[], label: string}>
     */
    private function slotsForWorkoutType(string $workoutType): array
    {
        $family = preg_replace('/_[abc]$/', '', $workoutType);

        return match ($family) {
            'full_body' => [
                ['patterns' => ['knee_dominant', 'full_body'], 'label' => 'knee_dominant'],
                ['patterns' => ['hip_dominant', 'full_body'], 'label' => 'hip_dominant'],
                ['patterns' => ['horizontal_push', 'full_body'], 'label' => 'horizontal_push'],
                ['patterns' => ['horizontal_pull', 'vertical_pull', 'full_body'], 'label' => 'horizontal_pull_or_vertical_pull'],
                ['patterns' => ['vertical_push', 'accessory', 'full_body'], 'label' => 'vertical_push_or_accessory_upper'],
                ['patterns' => ['core', 'full_body'], 'label' => 'core'],
            ],
            'upper' => [
                ['patterns' => ['horizontal_push'], 'label' => 'horizontal_push'],
                ['patterns' => ['vertical_push'], 'label' => 'vertical_push'],
                ['patterns' => ['horizontal_pull'], 'label' => 'horizontal_pull'],
                ['patterns' => ['vertical_pull'], 'label' => 'vertical_pull'],
                ['patterns' => ['accessory'], 'label' => 'accessory'],
                ['patterns' => ['core'], 'label' => 'core'],
            ],
            'lower' => [
                ['patterns' => ['knee_dominant'], 'label' => 'knee_dominant'],
                ['patterns' => ['hip_dominant'], 'label' => 'hip_dominant'],
                ['patterns' => ['knee_dominant'], 'label' => 'knee_dominant_2'],
                ['patterns' => ['core'], 'label' => 'core'],
                ['patterns' => ['accessory'], 'label' => 'accessory'],
            ],
            'push' => [
                ['patterns' => ['horizontal_push'], 'label' => 'horizontal_push'],
                ['patterns' => ['vertical_push'], 'label' => 'vertical_push'],
                ['patterns' => ['horizontal_push'], 'label' => 'horizontal_push_2'],
                ['patterns' => ['accessory'], 'label' => 'accessory_triceps'],
                ['patterns' => ['core'], 'label' => 'core'],
            ],
            'pull' => [
                ['patterns' => ['vertical_pull'], 'label' => 'vertical_pull'],
                ['patterns' => ['horizontal_pull'], 'label' => 'horizontal_pull'],
                ['patterns' => ['horizontal_pull'], 'label' => 'horizontal_pull_2'],
                ['patterns' => ['accessory'], 'label' => 'accessory_biceps'],
                ['patterns' => ['core'], 'label' => 'core'],
            ],
            'legs' => [
                ['patterns' => ['knee_dominant'], 'label' => 'knee_dominant'],
                ['patterns' => ['hip_dominant'], 'label' => 'hip_dominant'],
                ['patterns' => ['knee_dominant'], 'label' => 'knee_dominant_2'],
                ['patterns' => ['core'], 'label' => 'core'],
                ['patterns' => ['accessory'], 'label' => 'accessory'],
            ],
            default => [
                ['patterns' => ['full_body'], 'label' => 'full_body'],
            ],
        };
    }

    /**
     * Select the best exercise for a single slot.
     *
     * Follows the rule pipeline: pattern match (pools tried in order) ->
     * exclude -> equipment -> difficulty -> variety -> score -> pick highest.
     */
    private function selectExerciseForSlot(
        array $slot,
        array $allowedEquipment,
        array $allowedDifficulties,
        string $mappedGoal,
        array $usedExerciseIds,
        array $includedExerciseIds,
        array $excludedExerciseIds
    ): ?Exercise {
        // Try each pattern pool in order ("X OR Y").
        foreach ($slot['patterns'] as $pattern) {
            $candidates = Exercise::where('movement_pattern', $pattern)
                ->whereIn('equipment', $allowedEquipment)
                ->whereIn('difficulty', $allowedDifficulties)
                ->get();

            // Remove excluded IDs.
            $candidates = $candidates->reject(
                fn (Exercise $e) => in_array($e->id, $excludedExerciseIds, true)
            );

            // Variety: drop already-used exercises unless explicitly included.
            $candidates = $candidates->reject(
                fn (Exercise $e) => in_array($e->id, $usedExerciseIds, true)
                    && !in_array($e->id, $includedExerciseIds, true)
            );

            if ($candidates->isEmpty()) {
                continue;
            }

            $best = null;
            $bestScore = PHP_INT_MIN;
            foreach ($candidates as $candidate) {
                $score = $this->scoreCandidate(
                    $candidate,
                    $mappedGoal,
                    $usedExerciseIds,
                    $includedExerciseIds
                );
                if ($score > $bestScore) {
                    $bestScore = $score;
                    $best = $candidate;
                }
            }

            if ($best !== null) {
                return $best;
            }
        }

        return null;
    }

    /**
     * Score a candidate exercise for slot selection.
     */
    private function scoreCandidate(
        Exercise $exercise,
        string $mappedGoal,
        array $usedExerciseIds,
        array $includedExerciseIds
    ): int {
        $score = 0;

        if (in_array($exercise->id, $includedExerciseIds, true)) {
            $score += 100;
        }

        $goals = $exercise->goals ?? [];
        if (is_array($goals) && in_array($mappedGoal, $goals, true)) {
            $score += 30;
        }

        if (!in_array($exercise->id, $usedExerciseIds, true)) {
            $score += 20;
        }

        if ($exercise->exercise_type === 'compound') {
            $score += 10;
        }

        // Small tie-breaker randomness so equally-valid candidates vary.
        $score += random_int(0, 5);

        return $score;
    }

    /**
     * Build the output exercise list with sets/reps/duration/order.
     *
     * @param  Exercise[]  $exercises
     * @return array<int, array{exercise_id:int, sets:int, reps:int, duration_seconds:int, order:int}>
     */
    private function buildExerciseList(array $exercises, string $goal, string $fitnessLevel, float $adaptationFactor): array
    {
        $repRange = self::REPS_BY_GOAL[$goal] ?? self::REPS_BY_GOAL['stay_fit'];
        $setRange = self::SETS_BY_LEVEL[$fitnessLevel] ?? self::SETS_BY_LEVEL['intermediate'];

        $list = [];
        $order = 1;
        foreach ($exercises as $exercise) {
            $baseSets = random_int($setRange['min'], $setRange['max']);
            $sets = $this->applyAdaptation($baseSets, $adaptationFactor, $setRange['min'], $setRange['max'] + 1);

            $durationSeconds = (int) ($exercise->default_duration_seconds ?? 0);

            if ($durationSeconds > 0) {
                // Duration-based exercise (e.g. Plank): keep its default reps.
                $reps = (int) ($exercise->default_reps ?? 1);
            } else {
                $baseReps = random_int($repRange['min'], $repRange['max']);
                $reps = $this->applyAdaptation($baseReps, $adaptationFactor, $repRange['min'], $repRange['max']);
            }

            $list[] = [
                'exercise_id' => (int) $exercise->id,
                'sets' => $sets,
                'reps' => $reps,
                'duration_seconds' => $durationSeconds,
                'order' => $order,
            ];
            $order++;
        }

        return $list;
    }

    /**
     * Compute estimated workout duration in minutes.
     * Roughly: sets * (reps * 3s) + ~60s rest between sets + 30s transition
     * per exercise. Rounded up, minimum 1.
     */
    private function calculateDuration(array $exercises): int
    {
        $totalSeconds = 0;
        $restBetweenSets = 60;

        foreach ($exercises as $exercise) {
            $sets = (int) $exercise['sets'];
            $reps = (int) $exercise['reps'];
            $duration = (int) $exercise['duration_seconds'];

            if ($duration > 0) {
                $workTime = $sets * $duration;
            } else {
                $workTime = $sets * ($reps * 3);
            }

            $restTime = max(0, $sets - 1) * $restBetweenSets;
            $totalSeconds += $workTime + $restTime + 30; // 30s transition per exercise
        }

        return max(1, (int) ceil($totalSeconds / 60));
    }

    /**
     * Best-effort remediation to cover any required muscle at 0 for the week.
     *
     * Attempts to swap a full-body or accessory slot exercise for one that
     * covers a missing muscle. Non-fatal: if no swap is possible it is left.
     */
    private function ensureMuscleCoverage(
        array &$workouts,
        array &$usedExerciseIds,
        array $allowedEquipment,
        array $allowedDifficulties,
        string $mappedGoal,
        string $goal,
        string $fitnessLevel,
        float $adaptationFactor,
        array $excludedExerciseIds,
        array $includedExerciseIds
    ): void {
        foreach (self::REQUIRED_MUSCLES as $muscle) {
            $coverage = $this->computeCoverage($workouts);
            if (($coverage[$muscle] ?? 0.0) > 0.0) {
                continue;
            }

            // Find an exercise covering this muscle that respects filters.
            $replacement = Exercise::whereIn('equipment', $allowedEquipment)
                ->whereIn('difficulty', $allowedDifficulties)
                ->get()
                ->reject(fn (Exercise $e) => in_array($e->id, $excludedExerciseIds, true))
                ->first(function (Exercise $e) use ($muscle) {
                    $primary = $e->primary_muscles ?? [];
                    $secondary = $e->secondary_muscles ?? [];
                    return in_array($muscle, $primary, true) || in_array($muscle, $secondary, true);
                });

            if ($replacement === null) {
                continue;
            }

            // Find a swappable slot: prefer a full_body or accessory exercise.
            $swapped = false;
            foreach ($workouts as $wIndex => $workout) {
                foreach ($workout['_selected'] as $sIndex => $selected) {
                    $pattern = $selected->movement_pattern;
                    if (in_array($pattern, ['full_body', 'accessory'], true)) {
                        // Perform the swap.
                        $workouts[$wIndex]['_selected'][$sIndex] = $replacement;
                        $swapped = true;
                        break 2;
                    }
                }
            }

            if ($swapped) {
                // Rebuild the affected workout's exercise list + duration.
                $exerciseList = $this->buildExerciseList(
                    array_values($workouts[$wIndex]['_selected']),
                    $goal,
                    $fitnessLevel,
                    $adaptationFactor
                );
                $workouts[$wIndex]['exercises'] = $exerciseList;
                $workouts[$wIndex]['estimated_duration_minutes'] = $this->calculateDuration($exerciseList);
                $usedExerciseIds[] = $replacement->id;
            }
        }
    }

    /**
     * Compute weekly muscle coverage from selected exercise models.
     * primary_muscles weight 1.0, secondary_muscles weight 0.5.
     *
     * @return array<string, float>
     */
    private function computeCoverage(array $workouts): array
    {
        $coverage = array_fill_keys(self::REQUIRED_MUSCLES, 0.0);

        foreach ($workouts as $workout) {
            foreach ($workout['_selected'] as $exercise) {
                foreach (($exercise->primary_muscles ?? []) as $muscle) {
                    if (array_key_exists($muscle, $coverage)) {
                        $coverage[$muscle] += 1.0;
                    }
                }
                foreach (($exercise->secondary_muscles ?? []) as $muscle) {
                    if (array_key_exists($muscle, $coverage)) {
                        $coverage[$muscle] += 0.5;
                    }
                }
            }
        }

        return $coverage;
    }

    /**
     * Apply an adaptation factor to a base volume value.
     * Rounds and clamps within the given bounds.
     */
    private function applyAdaptation(int $baseValue, float $factor, int $min, int $max): int
    {
        if ($factor === 1.0) {
            return max($min, min($max, $baseValue));
        }

        $adapted = (int) round($baseValue * $factor);

        if ($factor > 1.0 && $adapted <= $baseValue && $baseValue < $max) {
            $adapted = $baseValue + 1;
        }

        if ($factor < 1.0 && $adapted >= $baseValue && $baseValue > $min) {
            $adapted = $baseValue - 1;
        }

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

        $recentHistory = WorkoutHistory::where('user_id', $user->id)
            ->where('completed_at', '>=', $twoWeeksAgo)
            ->get();

        if ($recentHistory->count() < 2) {
            return 1.0;
        }

        $totalExercises = 0;
        $completedCount = 0;
        $skippedCount = 0;

        foreach ($recentHistory as $record) {
            $exercises = $record->exercises_completed ?? [];
            foreach ($exercises as $exercise) {
                $totalExercises++;
                if (isset($exercise['skipped']) && $exercise['skipped'] === true) {
                    $skippedCount++;
                } else {
                    $completedCount++;
                }
            }
        }

        if ($totalExercises === 0) {
            return 1.0;
        }

        $completionRate = $completedCount / $totalExercises;
        $skipRate = $skippedCount / $totalExercises;

        if ($completionRate >= 0.80) {
            $scaleFactor = min(1.0, ($completionRate - 0.80) / 0.20);
            return 1.05 + ($scaleFactor * 0.05);
        }

        if ($skipRate >= 0.50) {
            $scaleFactor = min(1.0, ($skipRate - 0.50) / 0.50);
            return 0.95 - ($scaleFactor * 0.05);
        }

        return 1.0;
    }

    /**
     * Get allowed difficulty levels based on fitness level.
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
}
