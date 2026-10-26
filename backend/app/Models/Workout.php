<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A workout plan.
 *
 * 3NF note: the prescribed exercises live in the related `workout_exercises`
 * table, not an inline JSON column. To preserve the existing API/JSON contract
 * (and the Flutter client + offline cache), this model exposes a virtual
 * `exercises` attribute that reads from / writes to that relation. Consumers
 * keep using `$workout->exercises` as an array of
 * {exercise_id, sets, reps, duration_seconds, rest_seconds, order}.
 */
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

    protected $appends = ['exercises'];

    /** Pending exercises array captured by the mutator, flushed after save. */
    protected ?array $pendingExercises = null;

    protected function casts(): array
    {
        return [
            'is_generated' => 'boolean',
            'is_accepted' => 'boolean',
            'accepted_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        // Persist the virtual exercises to the junction table after the parent
        // row exists (so workout_id is available for the child rows).
        static::saved(function (Workout $workout): void {
            if ($workout->pendingExercises === null) {
                return;
            }
            $workout->syncExercises($workout->pendingExercises);
            $workout->pendingExercises = null;
            $workout->unsetRelation('workoutExercises');
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function workoutExercises()
    {
        return $this->hasMany(WorkoutExercise::class)->orderBy('position');
    }

    /**
     * Accessor: expose the related rows in the legacy JSON shape.
     *
     * @return array<int, array<string, int>>
     */
    public function getExercisesAttribute(): array
    {
        // Prefer the in-flight pending value during the same request so a read
        // immediately after assignment reflects what was set.
        if ($this->pendingExercises !== null) {
            return array_values($this->pendingExercises);
        }

        return $this->workoutExercises
            ->map(fn (WorkoutExercise $we) => [
                'exercise_id' => (int) $we->exercise_id,
                'sets' => (int) $we->sets,
                'reps' => (int) $we->reps,
                'duration_seconds' => (int) $we->duration_seconds,
                'rest_seconds' => (int) $we->rest_seconds,
                'order' => (int) $we->position,
            ])
            ->values()
            ->all();
    }

    /**
     * Mutator: accept the legacy JSON array; defer persistence until saved().
     *
     * @param array<int, array<string, mixed>>|null $value
     */
    public function setExercisesAttribute(?array $value): void
    {
        $this->pendingExercises = $value === null ? [] : array_values($value);
    }

    /**
     * Replaces this workout's exercise rows with the provided legacy-shaped
     * array. Rows missing an `order` are positioned by their index (1-based).
     *
     * @param array<int, array<string, mixed>> $exercises
     */
    public function syncExercises(array $exercises): void
    {
        $this->workoutExercises()->delete();

        $rows = [];
        $position = 0;
        foreach ($exercises as $item) {
            $position++;
            $rows[] = [
                'workout_id' => $this->id,
                'exercise_id' => (int) ($item['exercise_id'] ?? 0),
                'sets' => (int) ($item['sets'] ?? 0),
                'reps' => (int) ($item['reps'] ?? 0),
                'duration_seconds' => (int) ($item['duration_seconds'] ?? 0),
                'rest_seconds' => (int) ($item['rest_seconds'] ?? 0),
                'position' => (int) ($item['order'] ?? $position),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        if ($rows !== []) {
            WorkoutExercise::insert($rows);
        }
    }
}
