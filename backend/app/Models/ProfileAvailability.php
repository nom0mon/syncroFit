<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A single available workout day for a profile (3NF replacement for the
 * former profiles.availability_days JSON column).
 */
class ProfileAvailability extends Model
{
    use HasFactory;

    protected $table = 'profile_availability';

    protected $fillable = [
        'profile_id',
        'day_of_week',
    ];

    public function profile()
    {
        return $this->belongsTo(Profile::class);
    }
}
