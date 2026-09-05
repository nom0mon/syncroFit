<?php

namespace App\Services;

use App\Models\Exercise;

class WorkoutPrescriptionPolicy
{
    private const SETS = [
        'beginner' => 2,
        'intermediate' => 3,
        'advanced' => 3,
    ];

    /**
     * Build one deterministic, server-owned workout exercise prescription.
     */
    public function prescribe(Exercise $exercise, string $fitnessLevel, string $goal, int $order): array
    {
        $sets = self::SETS[$fitnessLevel] ?? self::SETS['intermediate'];
        $isTimed = (int) ($exercise->default_duration_seconds ?? 0) > 0;
        $isCompound = $exercise->exercise_type === 'compound';

        if ($isTimed) {
            $duration = match ($fitnessLevel) {
                'beginner' => 20,
                'advanced' => 45,
                default => 30,
            };

            return $this->payload($exercise, $sets, max(1, (int) ($exercise->default_reps ?? 1)), $duration, 90, $order);
        }

        [$reps, $rest] = match ($goal) {
            'build_muscle' => $isCompound ? [10, 150] : [15, 90],
            'increase_stamina' => [match ($fitnessLevel) {
                'beginner' => 12,
                'advanced' => 20,
                default => 16,
            }, $isCompound ? 90 : 60],
            default => [10, $isCompound ? 120 : 90],
        };

        // Advanced users retain adequate rest; experience never shortens it.
        if ($fitnessLevel === 'advanced' && $isCompound) {
            $rest = max($rest, 120);
        }

        return $this->payload($exercise, $sets, $reps, 0, $rest, $order);
    }

    private function payload(Exercise $exercise, int $sets, int $reps, int $duration, int $rest, int $order): array
    {
        return [
            'exercise_id' => (int) $exercise->id,
            'sets' => $sets,
            'reps' => $reps,
            'duration_seconds' => $duration,
            'rest_seconds' => $rest,
            'order' => $order,
        ];
    }

    public function estimatedDurationMinutes(array $exercises): int
    {
        $seconds = 0;
        foreach ($exercises as $exercise) {
            $sets = (int) $exercise['sets'];
            $work = (int) $exercise['duration_seconds'] > 0
                ? $sets * (int) $exercise['duration_seconds']
                : $sets * (int) $exercise['reps'] * 3;
            $seconds += $work + max(0, $sets - 1) * (int) $exercise['rest_seconds'] + 30;
        }

        return max(1, (int) ceil($seconds / 60));
    }
}
