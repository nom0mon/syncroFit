<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkoutExercise extends Model
{
    use HasFactory;

    protected $fillable = [
        'workout_id',
        'exercise_id',
        'sets',
        'reps',
        'rest_seconds',
        'order',
    ];

    protected function casts(): array
    {
        return [
            'sets' => 'integer',
            'reps' => 'integer',
            'rest_seconds' => 'integer',
            'order' => 'integer',
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
