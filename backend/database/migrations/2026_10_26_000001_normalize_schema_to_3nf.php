<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Normalizes the schema to 3NF by replacing three denormalized JSON columns
 * with proper relational tables that carry real foreign keys:
 *
 *   - profiles.availability_days (JSON)       -> profile_availability
 *   - workouts.exercises (JSON)               -> workout_exercises (FK -> exercises)
 *   - workout_history.exercises_completed(JSON)-> workout_history_exercises (FK -> exercises)
 *
 * It also removes the derived profiles.bmi column (a transitive dependency on
 * height_cm/weight_kg) so BMI is computed on read instead of stored.
 *
 * The up() migration backfills the new tables from existing JSON data before
 * dropping the old columns, so no data is lost. The down() migration rebuilds
 * the JSON columns from the normalized tables.
 *
 * Backfill safety:
 *   - workout_exercises / workout_history_exercises only link an exercise_id
 *     that still exists in `exercises` (older plans may reference exercises
 *     that have since been removed from the catalog). Orphaned references are
 *     skipped for the FK-bearing rows; workout_history keeps a snapshot
 *     exercise_name column so historical records remain complete regardless.
 */
return new class extends Migration
{
    public function up(): void
    {
        // ──────────────────────────────────────────────────────────────────
        // 1. Create the normalized tables
        // ──────────────────────────────────────────────────────────────────
        Schema::create('profile_availability', function (Blueprint $table) {
            $table->id();
            $table->foreignId('profile_id')->constrained('profiles')->cascadeOnDelete();
            $table->string('day_of_week', 10); // monday..sunday
            $table->timestamps();

            $table->unique(['profile_id', 'day_of_week']);
            $table->index('profile_id');
        });

        Schema::create('workout_exercises', function (Blueprint $table) {
            $table->id();
            $table->foreignId('workout_id')->constrained('workouts')->cascadeOnDelete();
            $table->foreignId('exercise_id')->constrained('exercises')->cascadeOnDelete();
            $table->unsignedInteger('sets');
            $table->unsignedInteger('reps');
            $table->unsignedInteger('duration_seconds')->default(0);
            $table->unsignedInteger('rest_seconds')->default(0);
            $table->unsignedInteger('position'); // 1-based order within the plan
            $table->timestamps();

            $table->unique(['workout_id', 'position']);
            $table->index('workout_id');
            $table->index('exercise_id');
        });

        Schema::create('workout_history_exercises', function (Blueprint $table) {
            $table->id();
            $table->foreignId('workout_history_id')->constrained('workout_history')->cascadeOnDelete();
            // Nullable + nullOnDelete: a completed session must survive even if
            // the referenced exercise is later removed from the catalog. The
            // snapshot name below preserves what the user actually performed.
            $table->foreignId('exercise_id')->nullable()->constrained('exercises')->nullOnDelete();
            $table->string('exercise_name'); // snapshot at completion time
            $table->unsignedInteger('sets_completed')->default(0);
            $table->unsignedInteger('reps_or_duration')->default(0);
            $table->boolean('is_duration')->default(false);
            $table->unsignedInteger('position'); // 1-based order within the session
            $table->timestamps();

            $table->index('workout_history_id');
            $table->index('exercise_id');
        });

        // ──────────────────────────────────────────────────────────────────
        // 2. Backfill from existing JSON data
        // ──────────────────────────────────────────────────────────────────
        $existingExerciseIds = DB::table('exercises')->pluck('id')->flip();

        // 2a. profiles.availability_days -> profile_availability
        DB::table('profiles')->orderBy('id')->chunkById(200, function ($profiles) {
            $rows = [];
            $now = now();
            foreach ($profiles as $profile) {
                $days = json_decode($profile->availability_days ?? '[]', true) ?: [];
                foreach (array_unique(array_map('strtolower', $days)) as $day) {
                    $rows[] = [
                        'profile_id' => $profile->id,
                        'day_of_week' => $day,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }
            if ($rows !== []) {
                DB::table('profile_availability')->insert($rows);
            }
        });

        // 2b. workouts.exercises -> workout_exercises
        DB::table('workouts')->orderBy('id')->chunkById(200, function ($workouts) use ($existingExerciseIds) {
            $rows = [];
            $now = now();
            foreach ($workouts as $workout) {
                $items = json_decode($workout->exercises ?? '[]', true) ?: [];
                $position = 0;
                foreach ($items as $item) {
                    $exerciseId = (int) ($item['exercise_id'] ?? 0);
                    // FK is non-nullable here; skip rows whose exercise no
                    // longer exists in the catalog.
                    if (!$existingExerciseIds->has($exerciseId)) {
                        continue;
                    }
                    $position++;
                    $rows[] = [
                        'workout_id' => $workout->id,
                        'exercise_id' => $exerciseId,
                        'sets' => (int) ($item['sets'] ?? 0),
                        'reps' => (int) ($item['reps'] ?? 0),
                        'duration_seconds' => (int) ($item['duration_seconds'] ?? 0),
                        'rest_seconds' => (int) ($item['rest_seconds'] ?? 0),
                        'position' => (int) ($item['order'] ?? $position),
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }
            if ($rows !== []) {
                DB::table('workout_exercises')->insert($rows);
            }
        });

        // 2c. workout_history.exercises_completed -> workout_history_exercises
        DB::table('workout_history')->orderBy('id')->chunkById(200, function ($records) use ($existingExerciseIds) {
            $rows = [];
            $now = now();
            foreach ($records as $record) {
                $items = json_decode($record->exercises_completed ?? '[]', true) ?: [];
                $position = 0;
                foreach ($items as $item) {
                    $position++;
                    $exerciseId = (int) ($item['exercise_id'] ?? 0);
                    $rows[] = [
                        'workout_history_id' => $record->id,
                        // nullOnDelete FK: keep the link only if still valid,
                        // otherwise null (snapshot name preserves the record).
                        'exercise_id' => $existingExerciseIds->has($exerciseId) ? $exerciseId : null,
                        'exercise_name' => (string) ($item['exercise_name'] ?? 'Unknown exercise'),
                        'sets_completed' => (int) ($item['sets_completed'] ?? 0),
                        'reps_or_duration' => (int) ($item['reps_or_duration'] ?? 0),
                        'is_duration' => (bool) ($item['is_duration'] ?? false),
                        'position' => $position,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
            }
            if ($rows !== []) {
                DB::table('workout_history_exercises')->insert($rows);
            }
        });

        // ──────────────────────────────────────────────────────────────────
        // 3. Drop the now-redundant denormalized columns
        // ──────────────────────────────────────────────────────────────────
        Schema::table('profiles', function (Blueprint $table) {
            $table->dropColumn(['availability_days', 'bmi']);
        });
        Schema::table('workouts', function (Blueprint $table) {
            $table->dropColumn('exercises');
        });
        Schema::table('workout_history', function (Blueprint $table) {
            $table->dropColumn('exercises_completed');
        });
    }

    public function down(): void
    {
        // ──────────────────────────────────────────────────────────────────
        // 1. Re-add the JSON columns (bmi stays nullable; recomputed below)
        // ──────────────────────────────────────────────────────────────────
        Schema::table('profiles', function (Blueprint $table) {
            $table->json('availability_days')->nullable()->after('workout_preference');
            $table->decimal('bmi', 5, 2)->nullable()->after('availability_days');
        });
        Schema::table('workouts', function (Blueprint $table) {
            $table->json('exercises')->nullable()->after('estimated_duration_minutes');
        });
        Schema::table('workout_history', function (Blueprint $table) {
            $table->json('exercises_completed')->nullable()->after('total_duration_seconds');
        });

        // ──────────────────────────────────────────────────────────────────
        // 2. Rebuild JSON from the normalized tables
        // ──────────────────────────────────────────────────────────────────
        // 2a. profile_availability + recompute bmi
        DB::table('profiles')->orderBy('id')->chunkById(200, function ($profiles) {
            foreach ($profiles as $profile) {
                $days = DB::table('profile_availability')
                    ->where('profile_id', $profile->id)
                    ->pluck('day_of_week')
                    ->all();

                $bmi = null;
                if ($profile->height_cm > 0) {
                    $bmi = round($profile->weight_kg / pow($profile->height_cm / 100, 2), 2);
                }

                DB::table('profiles')->where('id', $profile->id)->update([
                    'availability_days' => json_encode($days),
                    'bmi' => $bmi,
                ]);
            }
        });

        // 2b. workout_exercises -> workouts.exercises
        DB::table('workouts')->orderBy('id')->chunkById(200, function ($workouts) {
            foreach ($workouts as $workout) {
                $items = DB::table('workout_exercises')
                    ->where('workout_id', $workout->id)
                    ->orderBy('position')
                    ->get()
                    ->map(fn ($r) => [
                        'exercise_id' => (int) $r->exercise_id,
                        'sets' => (int) $r->sets,
                        'reps' => (int) $r->reps,
                        'duration_seconds' => (int) $r->duration_seconds,
                        'rest_seconds' => (int) $r->rest_seconds,
                        'order' => (int) $r->position,
                    ])
                    ->all();

                DB::table('workouts')->where('id', $workout->id)->update([
                    'exercises' => json_encode($items),
                ]);
            }
        });

        // 2c. workout_history_exercises -> workout_history.exercises_completed
        DB::table('workout_history')->orderBy('id')->chunkById(200, function ($records) {
            foreach ($records as $record) {
                $items = DB::table('workout_history_exercises')
                    ->where('workout_history_id', $record->id)
                    ->orderBy('position')
                    ->get()
                    ->map(fn ($r) => [
                        'exercise_id' => (string) ($r->exercise_id ?? ''),
                        'exercise_name' => $r->exercise_name,
                        'sets_completed' => (int) $r->sets_completed,
                        'reps_or_duration' => (int) $r->reps_or_duration,
                        'is_duration' => (bool) $r->is_duration,
                    ])
                    ->all();

                DB::table('workout_history')->where('id', $record->id)->update([
                    'exercises_completed' => json_encode($items),
                ]);
            }
        });

        // ──────────────────────────────────────────────────────────────────
        // 3. Drop the normalized tables
        // ──────────────────────────────────────────────────────────────────
        Schema::dropIfExists('workout_history_exercises');
        Schema::dropIfExists('workout_exercises');
        Schema::dropIfExists('profile_availability');
    }
};
