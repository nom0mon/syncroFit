<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Recommendation extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'week_start',
        'plan_data',
    ];

    protected function casts(): array
    {
        return [
            'week_start' => 'date',
            'plan_data' => 'array',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function workouts()
    {
        return $this->hasMany(Workout::class);
    }
}
