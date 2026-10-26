<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Junction row linking a workout to a prescribed exercise (3NF replacement
 * for the former workouts.exercises JSON column).
 */
class WorkoutExercise extends Model
{
    use HasFactory;

    protected $fillable = [
        'workout_id',
        'exercise_id',
        'sets',
        'reps',
        'duration_seconds',
        'rest_seconds',
        'position',
    ];

    protected function casts(): array
    {
        return [
            'exercise_id' => 'integer',
            'sets' => 'integer',
            'reps' => 'integer',
            'duration_seconds' => 'integer',
            'rest_seconds' => 'integer',
            'position' => 'integer',
        ];
    }

    public function workout()
    {
        return $this->belongsTo(Workout::class);
    }

    public function exercise()
    {
        return $this->belongsTo(Exercise::class);
    }
}
