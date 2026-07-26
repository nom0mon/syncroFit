<?php

namespace App\Http\Controllers;

use App\Models\Exercise;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ExerciseController extends Controller
{
    /**
     * Valid enum values for filtering.
     */
    private const VALID_MUSCLE_GROUPS = [
        'chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'core', 'full_body',
    ];

    private const VALID_DIFFICULTIES = [
        'beginner', 'intermediate', 'advanced',
    ];

    /**
     * List exercises with pagination and filtering.
     *
     * GET /api/exercises
     * Query params: page, page_size, muscle_group, equipment, difficulty
     */
    public function index(Request $request): JsonResponse
    {
        $pageSize = (int) ($request->query('page_size', 20));
        if ($pageSize < 1) {
            $pageSize = 20;
        }

        // Treat page < 1 as page 1
        $page = (int) ($request->query('page', 1));
        if ($page < 1) {
            $page = 1;
        }

        $query = Exercise::query();

        // Filter by muscle_group — ignore invalid enum values
        $muscleGroup = $request->query('muscle_group');
        if ($muscleGroup !== null && in_array($muscleGroup, self::VALID_MUSCLE_GROUPS, true)) {
            $query->where('muscle_group', $muscleGroup);
        }

        // Filter by equipment — accept any string value
        $equipment = $request->query('equipment');
        if ($equipment !== null && $equipment !== '') {
            $query->where('equipment', $equipment);
        }

        // Filter by difficulty — ignore invalid enum values
        $difficulty = $request->query('difficulty');
        if ($difficulty !== null && in_array($difficulty, self::VALID_DIFFICULTIES, true)) {
            $query->where('difficulty', $difficulty);
        }

        // Order alphabetically by name
        $query->orderBy('name', 'asc');

        // Paginate
        $paginator = $query->paginate($pageSize, ['*'], 'page', $page);

        return $this->successResponse([
            'exercises' => $paginator->items(),
            'pagination' => [
                'current_page' => $paginator->currentPage(),
                'total_pages' => $paginator->lastPage(),
                'total_count' => $paginator->total(),
            ],
        ]);
    }

    /**
     * Show a single exercise.
     *
     * GET /api/exercises/{exercise}
     */
    public function show(Request $request, $exercise): JsonResponse
    {
        $exerciseModel = Exercise::findOrFail($exercise);

        return $this->successResponse($exerciseModel);
    }
}
