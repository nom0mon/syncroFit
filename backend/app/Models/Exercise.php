<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Exercise extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'description',
        'instructions',
        'muscle_group',
        'equipment',
        'difficulty',
        'default_sets',
        'default_reps',
        'default_duration_seconds',
        'video_path',
    ];

    protected function casts(): array
    {
        return [
            'instructions' => 'array',
            'default_sets' => 'integer',
            'default_reps' => 'integer',
            'default_duration_seconds' => 'integer',
        ];
    }
}
