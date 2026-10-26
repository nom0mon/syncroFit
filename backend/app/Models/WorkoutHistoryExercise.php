<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Junction row for a completed exercise within a workout_history record
 * (3NF replacement for the former workout_history.exercises_completed JSON).
 *
 * Carries a snapshot exercise_name so the record remains complete even if the
 * referenced exercise is later removed from the catalog (exercise_id is then
 * nulled via the migration's nullOnDelete FK).
 */
class WorkoutHistoryExercise extends Model
{
    use HasFactory;

    protected $fillable = [
        'workout_history_id',
        'exercise_id',
        'exercise_name',
        'sets_completed',
        'reps_or_duration',
        'is_duration',
        'position',
    ];

    protected function casts(): array
    {
        return [
            'exercise_id' => 'integer',
            'sets_completed' => 'integer',
            'reps_or_duration' => 'integer',
            'is_duration' => 'boolean',
            'position' => 'integer',
        ];
    }

    public function workoutHistory()
    {
        return $this->belongsTo(WorkoutHistory::class);
    }

    public function exercise()
    {
        return $this->belongsTo(Exercise::class);
    }
}
