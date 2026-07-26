<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkoutSession extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'workout_id',
        'status',
        'started_at',
        'completed_at',
        'total_duration_seconds',
        'pause_log',
    ];

    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'completed_at' => 'datetime',
            'total_duration_seconds' => 'integer',
            'pause_log' => 'array',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function workout()
    {
        return $this->belongsTo(Workout::class);
    }

    public function sessionExercises()
    {
        return $this->hasMany(SessionExercise::class);
    }
}
