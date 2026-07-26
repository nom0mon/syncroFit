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
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->unique()->words(3, true),
            'description' => fake()->sentence(),
            'instructions' => [fake()->sentence(), fake()->sentence()],
            'muscle_group' => fake()->randomElement(self::MUSCLE_GROUPS),
            'equipment' => fake()->randomElement(self::EQUIPMENT),
            'difficulty' => fake()->randomElement(self::DIFFICULTIES),
            'default_sets' => fake()->numberBetween(2, 5),
            'default_reps' => fake()->numberBetween(5, 20),
            'default_duration_seconds' => fake()->randomElement([null, 30, 45, 60]),
            'image_url' => null,
        ];
    }
}
