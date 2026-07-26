<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Workout extends Model
{
    use HasFactory;

    protected $fillable = [
        'recommendation_id',
        'name',
        'day_of_week',
        'estimated_duration_minutes',
    ];

    protected function casts(): array
    {
        return [
            'day_of_week' => 'integer',
            'estimated_duration_minutes' => 'integer',
        ];
    }

    public function recommendation()
    {
        return $this->belongsTo(Recommendation::class);
    }

    public function exercises()
    {
        return $this->hasMany(WorkoutExercise::class);
    }

    public function sessions()
    {
        return $this->hasMany(WorkoutSession::class);
    }
}
