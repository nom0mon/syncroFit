<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProgressRecord extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'recorded_at',
        'weight_kg',
        'bmi',
        'workouts_completed',
    ];

    protected function casts(): array
    {
        return [
            'recorded_at' => 'date',
            'weight_kg' => 'decimal:2',
            'bmi' => 'decimal:2',
            'workouts_completed' => 'integer',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
