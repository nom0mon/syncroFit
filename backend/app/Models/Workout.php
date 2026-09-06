<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Workout extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'plan_id',
        'name',
        'day_of_week',
        'estimated_duration_minutes',
        'exercises',
        'is_generated',
        'is_accepted',
        'accepted_at',
    ];

    protected function casts(): array
    {
        return [
            'exercises' => 'array',
            'is_generated' => 'boolean',
            'is_accepted' => 'boolean',
            'accepted_at' => 'datetime',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
