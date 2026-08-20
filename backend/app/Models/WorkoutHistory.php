<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkoutHistory extends Model
{
    use HasFactory;

    protected $table = 'workout_history';

    protected $fillable = [
        'user_id',
        'workout_name',
        'completed_at',
        'total_duration_seconds',
        'exercises_completed',
    ];

    protected function casts(): array
    {
        return [
            'exercises_completed' => 'array',
            'completed_at' => 'datetime',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
