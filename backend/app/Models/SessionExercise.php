<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SessionExercise extends Model
{
    use HasFactory;

    protected $fillable = [
        'workout_session_id',
        'exercise_id',
        'status',
        'sets_completed',
        'reps_completed',
    ];

    protected function casts(): array
    {
        return [
            'sets_completed' => 'integer',
            'reps_completed' => 'integer',
        ];
    }

    public function workoutSession()
    {
        return $this->belongsTo(WorkoutSession::class);
    }

    public function exercise()
    {
        return $this->belongsTo(Exercise::class);
    }
}
