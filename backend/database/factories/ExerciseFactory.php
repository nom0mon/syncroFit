<?php

namespace Database\Factories;

use App\Models\Exercise;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Exercise>
 */
class ExerciseFactory extends Factory
{
    protected $model = Exercise::class;

    private const MUSCLE_GROUPS = [
        'chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'core', 'full_body',
    ];

    private const DIFFICULTIES = [
        'beginner', 'intermediate', 'advanced',
    ];

    private const EQUIPMENT = [
        'bodyweight', 'dumbbell', 'barbell', 'kettlebell', 'resistance_band', 'machine', 'pull_up_bar',
    ];

    /**
     * Map a muscle group to a reasonable default movement pattern so that
     * factory-created exercises are usable by the movement-pattern-driven
     * RecommendationEngine.
     */
    private const MOVEMENT_PATTERN_BY_MUSCLE_GROUP = [
        'chest' => 'horizontal_push',
        'back' => 'horizontal_pull',
        'shoulders' => 'vertical_push',
        'biceps' => 'accessory',
        'triceps' => 'accessory',
        'legs' => 'knee_dominant',
        'core' => 'core',
        'full_body' => 'full_body',
    ];

    private const PRIMARY_MUSCLES_BY_MUSCLE_GROUP = [
        'chest' => ['chest'],
        'back' => ['back'],
        'shoulders' => ['shoulders'],
        'biceps' => ['biceps'],
        'triceps' => ['triceps'],
        'legs' => ['quadriceps'],
        'core' => ['core'],
        'full_body' => ['quadriceps', 'chest'],
    ];

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $muscleGroup = fake()->randomElement(self::MUSCLE_GROUPS);
        $equipment = fake()->randomElement(self::EQUIPMENT);

        return [
            'name' => fake()->unique()->words(3, true),
            'description' => fake()->sentence(),
            'instructions' => [fake()->sentence(), fake()->sentence()],
            'muscle_group' => $muscleGroup,
            'equipment' => $equipment,
            'environments' => match ($equipment) {
                'bodyweight' => ['home', 'gym', 'outdoor'],
                'dumbbell', 'kettlebell', 'resistance_band' => ['home', 'gym'],
                default => ['gym'],
            },
            'verification_status' => 'catalog_cross_checked',
            'source_reference' => 'https://github.com/yuhonas/free-exercise-db',
            'difficulty' => fake()->randomElement(self::DIFFICULTIES),
            'default_sets' => fake()->numberBetween(2, 5),
            'default_reps' => fake()->numberBetween(5, 20),
            'default_duration_seconds' => fake()->randomElement([30, 45, 60]),
            'video_path' => null,
            'movement_pattern' => self::MOVEMENT_PATTERN_BY_MUSCLE_GROUP[$muscleGroup] ?? 'accessory',
            'primary_muscles' => self::PRIMARY_MUSCLES_BY_MUSCLE_GROUP[$muscleGroup] ?? ['core'],
            'secondary_muscles' => [],
            'exercise_type' => fake()->randomElement(['compound', 'isolation']),
            'goals' => fake()->randomElements(
                ['muscle_gain', 'strength', 'general_fitness', 'fat_loss', 'endurance'],
                fake()->numberBetween(1, 3)
            ),
        ];
    }
}
