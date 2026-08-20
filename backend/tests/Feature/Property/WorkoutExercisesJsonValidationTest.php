<?php

namespace Tests\Feature\Property;

use App\Models\Exercise;
use Eris\Generators;
use Eris\TestTrait;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Validator;
use Tests\TestCase;

/**
 * Property Test: Workout exercises JSON validation (Property 3)
 *
 * Feature: database-simplification
 * Property 3: Workout exercises JSON validation
 *
 * For any JSON array where at least one object is missing any of the required fields
 * (exercise_id, sets, reps, duration_seconds, order), the workout validation SHALL reject
 * the input. Conversely, for any JSON array where all objects contain all required fields
 * with valid types, the validation SHALL accept the input.
 *
 * **Validates: Requirements 3.5**
 */
class WorkoutExercisesJsonValidationTest extends TestCase
{
    use RefreshDatabase;
    use TestTrait;

    /** @var array<int> Seeded exercise IDs available for validation */
    private array $exerciseIds = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->artisan('db:seed', ['--class' => 'Database\\Seeders\\ExerciseSeeder']);
        $this->exerciseIds = Exercise::pluck('id')->toArray();
    }

    /**
     * Returns the validation rules for workout creation, matching the WorkoutController's store method.
     */
    private function getWorkoutValidationRules(): array
    {
        return [
            'name' => 'required|string|max:255',
            'day_of_week' => 'nullable|string',
            'estimated_duration_minutes' => 'nullable|integer|min:1',
            'exercises' => 'required|array',
            'exercises.*.exercise_id' => 'required|integer|exists:exercises,id',
            'exercises.*.sets' => 'required|integer|min:1|max:20',
            'exercises.*.reps' => 'required|integer|min:1|max:100',
            'exercises.*.duration_seconds' => 'required|integer|min:0',
            'exercises.*.order' => 'required|integer|min:1',
        ];
    }

    /**
     * Property 3 (Part A): Valid exercises arrays pass validation.
     *
     * For any JSON array where all objects contain all required fields with valid types,
     * the validation SHALL accept the input.
     *
     * **Validates: Requirements 3.5**
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_complete_exercise_objects_pass_validation_property(): void
    {
        $this->limitTo(100);

        $this->forAll(
            $this->validExercisesArrayGenerator()
        )->then(function (array $exercises): void {
            $data = [
                'name' => 'Test Workout',
                'exercises' => $exercises,
            ];

            $validator = Validator::make($data, $this->getWorkoutValidationRules());

            $this->assertFalse(
                $validator->fails(),
                'Validation should pass for exercises with all required fields. ' .
                'Input: ' . json_encode($exercises) . ' Errors: ' . json_encode($validator->errors()->toArray())
            );
        });
    }

    /**
     * Property 3 (Part B): Exercises arrays with missing required fields fail validation.
     *
     * For any JSON array where at least one object is missing any of the required fields
     * (exercise_id, sets, reps, duration_seconds, order), the workout validation SHALL
     * reject the input.
     *
     * **Validates: Requirements 3.5**
     */
    #[\PHPUnit\Framework\Attributes\Group('database-simplification')]
    public function test_exercises_with_missing_fields_fail_validation_property(): void
    {
        $this->limitTo(100);

        $this->forAll(
            $this->invalidExercisesArrayGenerator()
        )->then(function (array $exercises): void {
            $data = [
                'name' => 'Test Workout',
                'exercises' => $exercises,
            ];

            $validator = Validator::make($data, $this->getWorkoutValidationRules());

            $this->assertTrue(
                $validator->fails(),
                'Validation should fail when at least one exercise object is missing a required field. ' .
                'Input: ' . json_encode($exercises) . ' Expected failure but validation passed.'
            );
        });
    }

    /**
     * Generate valid exercises arrays where all objects have all required fields
     * with values in valid ranges.
     *
     * Each exercise object has:
     * - exercise_id: valid ID from seeded exercises
     * - sets: integer 1-20
     * - reps: integer 1-100
     * - duration_seconds: integer >= 0
     * - order: integer >= 1
     */
    private function validExercisesArrayGenerator(): \Eris\Generator
    {
        $exerciseIds = $this->exerciseIds;

        return Generators::map(
            function (array $tuple) use ($exerciseIds): array {
                $count = ($tuple[0] % 5) + 1; // 1 to 5 exercises
                $exercises = [];

                for ($i = 0; $i < $count; $i++) {
                    $exercises[] = [
                        'exercise_id' => $exerciseIds[abs($tuple[1 + $i * 4]) % count($exerciseIds)],
                        'sets' => ($tuple[2 + $i * 4] % 20) + 1,           // 1-20
                        'reps' => ($tuple[3 + $i * 4] % 100) + 1,          // 1-100
                        'duration_seconds' => $tuple[4 + $i * 4] % 3601,   // 0-3600
                        'order' => $i + 1,                                  // sequential order
                    ];
                }

                return $exercises;
            },
            Generators::tuple(
                Generators::choose(0, 4),         // count seed (1-5)
                // 5 exercises * 4 fields = 20 values needed (max)
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600)
            )
        );
    }

    /**
     * Generate exercises arrays where at least one object is missing a required field.
     *
     * Strategy: Generate a valid array, then remove one required field from a random object.
     * The required fields are: exercise_id, sets, reps, duration_seconds, order.
     */
    private function invalidExercisesArrayGenerator(): \Eris\Generator
    {
        $exerciseIds = $this->exerciseIds;
        $requiredFields = ['exercise_id', 'sets', 'reps', 'duration_seconds', 'order'];

        return Generators::map(
            function (array $tuple) use ($exerciseIds, $requiredFields): array {
                $count = ($tuple[0] % 5) + 1; // 1 to 5 exercises
                $exercises = [];

                for ($i = 0; $i < $count; $i++) {
                    $exercises[] = [
                        'exercise_id' => $exerciseIds[abs($tuple[1 + $i * 4]) % count($exerciseIds)],
                        'sets' => ($tuple[2 + $i * 4] % 20) + 1,
                        'reps' => ($tuple[3 + $i * 4] % 100) + 1,
                        'duration_seconds' => $tuple[4 + $i * 4] % 3601,
                        'order' => $i + 1,
                    ];
                }

                // Remove a required field from one of the exercise objects
                $targetIndex = $tuple[21] % $count;
                $fieldToRemove = $requiredFields[$tuple[22] % count($requiredFields)];
                unset($exercises[$targetIndex][$fieldToRemove]);

                return $exercises;
            },
            Generators::tuple(
                Generators::choose(0, 4),         // count seed
                // 5 exercises * 4 fields = 20 values
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 1000), Generators::choose(1, 20), Generators::choose(1, 100), Generators::choose(0, 3600),
                Generators::choose(0, 100),       // target exercise index seed
                Generators::choose(0, 100)        // field to remove seed
            )
        );
    }
}
