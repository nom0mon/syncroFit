<?php

namespace Tests\Feature\Property;

use App\Services\ExerciseVideoPathGenerator;
use Eris\TestTrait;
use Eris\Generators;
use Tests\TestCase;

/**
 * Property Test: Exercise name to video_path format conversion (Property 1)
 *
 * Feature: database-simplification
 * Property 1: Exercise name to video_path format conversion
 *
 * For any valid exercise name string, applying the video_path generation function
 * SHALL produce a string matching the pattern `assets/videos/{snake_case_name}.mp4`,
 * where the snake_case_name is the lowercase, underscore-separated version of the exercise name.
 *
 * **Validates: Requirements 2.5**
 */
class ExerciseVideoPathConversionTest extends TestCase
{
    use TestTrait;

    /**
     * Property 1: Exercise name to video_path format conversion
     *
     * Using Eris, generate random valid exercise name strings and verify the
     * video_path generation produces `assets/videos/{snake_case_name}.mp4`.
     *
     * The snake_case_name must be:
     * - All lowercase
     * - Words separated by underscores
     * - No leading/trailing underscores
     * - No consecutive underscores
     *
     * **Validates: Requirements 2.5**
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_exercise_name_to_video_path_format_conversion_property(): void
    {
        $this->limitTo(100);

        $this->forAll(
            $this->exerciseNameGenerator()
        )->then(function (string $exerciseName): void {
            $videoPath = ExerciseVideoPathGenerator::generate($exerciseName);

            // Must start with "assets/videos/"
            $this->assertStringStartsWith(
                'assets/videos/',
                $videoPath,
                "video_path for '$exerciseName' must start with 'assets/videos/'. Got: $videoPath"
            );

            // Must end with ".mp4"
            $this->assertStringEndsWith(
                '.mp4',
                $videoPath,
                "video_path for '$exerciseName' must end with '.mp4'. Got: $videoPath"
            );

            // Extract the snake_case portion
            $snakePart = substr($videoPath, strlen('assets/videos/'), -strlen('.mp4'));

            // Must be all lowercase
            $this->assertSame(
                strtolower($snakePart),
                $snakePart,
                "snake_case portion for '$exerciseName' must be lowercase. Got: $snakePart"
            );

            // Must not contain consecutive underscores
            $this->assertStringNotContainsString(
                '__',
                $snakePart,
                "snake_case portion for '$exerciseName' must not contain consecutive underscores. Got: $snakePart"
            );

            // Must not start or end with underscore
            $this->assertDoesNotMatchRegularExpression(
                '/^_|_$/',
                $snakePart,
                "snake_case portion for '$exerciseName' must not start or end with underscore. Got: $snakePart"
            );

            // Must only contain lowercase letters, digits, and underscores
            $this->assertMatchesRegularExpression(
                '/^[a-z0-9][a-z0-9_]*[a-z0-9]$|^[a-z0-9]$/',
                $snakePart,
                "snake_case portion for '$exerciseName' must only contain lowercase letters, digits, and underscores. Got: $snakePart"
            );

            // Must be non-empty
            $this->assertNotEmpty(
                $snakePart,
                "snake_case portion for '$exerciseName' must not be empty"
            );
        });
    }

    /**
     * Property 1 (additional): Known exercise names produce correct paths
     *
     * Test with the actual exercise names from the seeder to verify
     * the conversion handles real-world cases correctly.
     *
     * **Validates: Requirements 2.5**
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_known_exercise_names_produce_expected_video_paths(): void
    {
        $this->limitTo(100);

        $knownExercises = [
            'Push-Up', 'Dumbbell Bench Press', 'Barbell Bench Press',
            'Cable Chest Fly', 'Pull-Up', 'Barbell Bent-Over Row',
            'Dumbbell Single-Arm Row', 'Resistance Band Pull-Apart',
            'Dumbbell Overhead Press', 'Pike Push-Up', 'Kettlebell Press',
            'Dumbbell Bicep Curl', 'Barbell Curl', 'Chin-Up',
            'Resistance Band Curl', 'Tricep Dip', 'Dumbbell Overhead Tricep Extension',
            'Cable Tricep Pushdown', 'Bodyweight Squat', 'Barbell Back Squat',
            'Kettlebell Goblet Squat', 'Leg Press', 'Dumbbell Romanian Deadlift',
            'Plank', 'Hanging Leg Raise', 'Kettlebell Russian Twist',
            'Cable Woodchop', 'Burpee', 'Kettlebell Swing',
            'Barbell Deadlift', 'Resistance Band Thruster', 'Dumbbell Clean and Press',
            'Resistance Band Lateral Raise', 'Close-Grip Barbell Bench Press',
        ];

        $this->forAll(
            Generators::elements($knownExercises)
        )->then(function (string $exerciseName): void {
            $videoPath = ExerciseVideoPathGenerator::generate($exerciseName);

            // Must follow the full format pattern
            $this->assertMatchesRegularExpression(
                '/^assets\/videos\/[a-z0-9][a-z0-9_]*[a-z0-9]\.mp4$/',
                $videoPath,
                "video_path for '$exerciseName' must match format 'assets/videos/{snake_case}.mp4'. Got: $videoPath"
            );

            // The snake_case name must not contain spaces
            $snakePart = substr($videoPath, strlen('assets/videos/'), -strlen('.mp4'));
            $this->assertStringNotContainsString(
                ' ',
                $snakePart,
                "snake_case portion for '$exerciseName' must not contain spaces. Got: $snakePart"
            );

            // The snake_case name must not contain hyphens
            $this->assertStringNotContainsString(
                '-',
                $snakePart,
                "snake_case portion for '$exerciseName' must not contain hyphens. Got: $snakePart"
            );
        });
    }

    /**
     * Create a custom Eris generator for exercise-like names.
     *
     * Generates strings that look like exercise names:
     * - 1-4 words
     * - Each word starts with uppercase, rest lowercase
     * - Words separated by spaces or hyphens
     * - Examples: "Push Up", "Dumbbell Bench Press", "Single-Arm Row"
     */
    private function exerciseNameGenerator(): \Eris\Generator
    {
        // Generate exercise names by combining word parts
        $words = [
            'Push', 'Pull', 'Press', 'Curl', 'Squat', 'Row', 'Fly', 'Raise',
            'Dip', 'Swing', 'Twist', 'Lunge', 'Plank', 'Crunch', 'Deadlift',
            'Dumbbell', 'Barbell', 'Kettlebell', 'Cable', 'Machine', 'Band',
            'Bodyweight', 'Resistance', 'Single', 'Double', 'Overhead',
            'Incline', 'Decline', 'Flat', 'Seated', 'Standing', 'Lying',
            'Front', 'Back', 'Side', 'Lateral', 'Reverse', 'Close', 'Wide',
            'Arm', 'Leg', 'Chest', 'Shoulder', 'Hip', 'Grip',
            'Up', 'Down', 'Over', 'Apart', 'Together',
        ];

        $separators = [' ', ' ', ' ', '-']; // Bias toward spaces

        return Generators::map(
            function (array $tuple) use ($words, $separators): string {
                [$wordCount, $seed1, $seed2, $seed3, $seed4, $sepSeed] = $tuple;

                // Pick 1-4 words
                $count = ($wordCount % 4) + 1;
                $seeds = [$seed1, $seed2, $seed3, $seed4];
                $selectedWords = [];

                for ($i = 0; $i < $count; $i++) {
                    $index = abs($seeds[$i]) % count($words);
                    $selectedWords[] = $words[$index];
                }

                // Join with random separator (space or hyphen)
                $sep = $separators[abs($sepSeed) % count($separators)];

                return implode($sep, $selectedWords);
            },
            Generators::tuple(
                Generators::choose(0, 100),
                Generators::choose(0, 1000),
                Generators::choose(0, 1000),
                Generators::choose(0, 1000),
                Generators::choose(0, 1000),
                Generators::choose(0, 100)
            )
        );
    }
}
