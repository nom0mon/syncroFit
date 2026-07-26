<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Profile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'age',
        'height_cm',
        'weight_kg',
        'gender',
        'goal',
        'fitness_level',
        'workout_preference',
        'availability_days',
        'bmi',
    ];

    protected function casts(): array
    {
        return [
            'age' => 'integer',
            'height_cm' => 'decimal:2',
            'weight_kg' => 'decimal:2',
            'availability_days' => 'array',
            'bmi' => 'decimal:2',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
