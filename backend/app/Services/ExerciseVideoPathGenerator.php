<?php

namespace App\Services;

use Illuminate\Support\Str;

/**
 * Generates video asset paths from exercise names.
 *
 * Converts an exercise name to a snake_case video path format:
 * "Push-Up" => "assets/videos/push_up.mp4"
 * "Dumbbell Bench Press" => "assets/videos/dumbbell_bench_press.mp4"
 */
class ExerciseVideoPathGenerator
{
    /**
     * Generate the video_path for a given exercise name.
     *
     * The conversion:
     * 1. Replace hyphens with spaces (so "Push-Up" becomes "Push Up")
     * 2. Apply Laravel's Str::snake() to convert to snake_case
     * 3. Prepend "assets/videos/" and append ".mp4"
     *
     * @param string $exerciseName The human-readable exercise name
     * @return string The video asset path
     */
    public static function generate(string $exerciseName): string
    {
        // Replace hyphens with spaces so Str::snake treats them as word separators
        $normalized = str_replace('-', ' ', $exerciseName);

        // Convert to snake_case (handles spaces, camelCase, etc.)
        $snakeName = Str::snake($normalized);

        // Clean up any double underscores that might result from multiple spaces
        $snakeName = preg_replace('/_+/', '_', $snakeName);

        // Trim leading/trailing underscores
        $snakeName = trim($snakeName, '_');

        return "assets/videos/{$snakeName}.mp4";
    }
}
