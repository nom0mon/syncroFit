<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A completed workout session.
 *
 * 3NF note: completed exercises live in the related
 * `workout_history_exercises` table, not an inline JSON column. This model
 * exposes a virtual `exercises_completed` attribute (read/write) that maps
 * to that relation, preserving the existing API/JSON contract and the Flutter
 * client + offline cache. Each entry keeps the legacy shape:
 * {exercise_id, exercise_name, sets_completed, reps_or_duration, is_duration}.
 */
class WorkoutHistory extends Model
{
    use HasFactory;

    protected $table = 'workout_history';

    protected $fillable = [
        'user_id',
        'client_mutation_id',
        'workout_name',
        'completed_at',
        'total_duration_seconds',
        'exercises_completed',
    ];

    protected $appends = ['exercises_completed'];

    /** Pending entries captured by the mutator, flushed after save. */
    protected ?array $pendingExercisesCompleted = null;

    protected function casts(): array
    {
        return [
            'completed_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::saved(function (WorkoutHistory $record): void {
            if ($record->pendingExercisesCompleted === null) {
                return;
            }
            $record->syncExercisesCompleted($record->pendingExercisesCompleted);
            $record->pendingExercisesCompleted = null;
            $record->unsetRelation('historyExercises');
        });
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function historyExercises()
    {
        return $this->hasMany(WorkoutHistoryExercise::class)->orderBy('position');
    }

    /**
     * Accessor: expose related rows in the legacy JSON shape.
     *
     * @return array<int, array<string, mixed>>
     */
    public function getExercisesCompletedAttribute(): array
    {
        if ($this->pendingExercisesCompleted !== null) {
            return array_values($this->pendingExercisesCompleted);
        }

        return $this->historyExercises
            ->map(fn (WorkoutHistoryExercise $e) => [
                'exercise_id' => $e->exercise_id === null ? '' : (string) $e->exercise_id,
                'exercise_name' => (string) $e->exercise_name,
                'sets_completed' => (int) $e->sets_completed,
                'reps_or_duration' => (int) $e->reps_or_duration,
                'is_duration' => (bool) $e->is_duration,
            ])
            ->values()
            ->all();
    }

    /**
     * Mutator: accept the legacy JSON array; defer persistence until saved().
     *
     * @param array<int, array<string, mixed>>|null $value
     */
    public function setExercisesCompletedAttribute(?array $value): void
    {
        $this->pendingExercisesCompleted = $value === null ? [] : array_values($value);
    }

    /**
     * Replaces this record's completed-exercise rows from a legacy-shaped array.
     *
     * @param array<int, array<string, mixed>> $entries
     */
    public function syncExercisesCompleted(array $entries): void
    {
        $this->historyExercises()->delete();

        // Only link exercise_ids that still exist in the catalog; keep the
        // snapshot name regardless so the record stays complete.
        $validIds = Exercise::whereIn('id', collect($entries)
            ->map(fn ($e) => (int) ($e['exercise_id'] ?? 0))
            ->filter()
            ->unique()
            ->all())->pluck('id')->flip();

        $rows = [];
        $position = 0;
        foreach ($entries as $entry) {
            $position++;
            $exerciseId = (int) ($entry['exercise_id'] ?? 0);
            $rows[] = [
                'workout_history_id' => $this->id,
                'exercise_id' => $validIds->has($exerciseId) ? $exerciseId : null,
                'exercise_name' => (string) ($entry['exercise_name'] ?? 'Unknown exercise'),
                'sets_completed' => (int) ($entry['sets_completed'] ?? 0),
                'reps_or_duration' => (int) ($entry['reps_or_duration'] ?? 0),
                'is_duration' => (bool) ($entry['is_duration'] ?? false),
                'position' => $position,
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        if ($rows !== []) {
            WorkoutHistoryExercise::insert($rows);
        }
    }
}
