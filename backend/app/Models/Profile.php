<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A member's fitness profile.
 *
 * 3NF notes:
 *  - availability_days is backed by the related `profile_availability` table,
 *    exposed here as a virtual array attribute to preserve the API contract.
 *  - bmi is a computed accessor (derived from height_cm/weight_kg), no longer
 *    a stored column, eliminating the former transitive dependency.
 */
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
    ];

    protected $appends = ['availability_days', 'bmi'];

    /** Pending availability captured by the mutator, flushed after save. */
    protected ?array $pendingAvailability = null;

    protected function casts(): array
    {
        return [
            'age' => 'integer',
            'height_cm' => 'decimal:2',
            'weight_kg' => 'decimal:2',
        ];
    }

    protected static function booted(): void
    {
        static::saved(function (Profile $profile): void {
            if ($profile->pendingAvailability === null) {
                return;
            }
            $profile->syncAvailability($profile->pendingAvailability);
            $profile->pendingAvailability = null;
            $profile->unsetRelation('availability');
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function availability()
    {
        return $this->hasMany(ProfileAvailability::class);
    }

    /**
     * Accessor: expose availability days as a lowercase string array.
     *
     * @return array<int, string>
     */
    public function getAvailabilityDaysAttribute(): array
    {
        if ($this->pendingAvailability !== null) {
            return array_values($this->pendingAvailability);
        }

        return $this->availability->pluck('day_of_week')->values()->all();
    }

    /**
     * Mutator: accept a string array; defer persistence until saved().
     *
     * @param array<int, string>|null $value
     */
    public function setAvailabilityDaysAttribute(?array $value): void
    {
        $this->pendingAvailability = $value === null
            ? []
            : collect($value)->map(fn ($d) => strtolower((string) $d))->unique()->values()->all();
    }

    /**
     * Computed BMI: weight_kg / (height_cm / 100)^2.
     *
     * Returned as a 2-decimal string to match the prior `decimal:2` column
     * serialization (e.g. "22.86"), preserving the API/JSON contract.
     */
    public function getBmiAttribute(): ?string
    {
        $height = (float) $this->height_cm;
        $weight = (float) $this->weight_kg;
        if ($height <= 0) {
            return null;
        }

        return number_format(round($weight / pow($height / 100, 2), 2), 2, '.', '');
    }

    /**
     * Replaces this profile's availability rows from a string array.
     *
     * @param array<int, string> $days
     */
    public function syncAvailability(array $days): void
    {
        $this->availability()->delete();

        $rows = [];
        foreach (collect($days)->map(fn ($d) => strtolower((string) $d))->unique() as $day) {
            $rows[] = [
                'profile_id' => $this->id,
                'day_of_week' => $day,
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        if ($rows !== []) {
            ProfileAvailability::insert($rows);
        }
    }
}
