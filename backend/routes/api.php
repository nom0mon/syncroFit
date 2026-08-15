<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| All API routes are loaded by the RouteServiceProvider within the "api"
| middleware group. All routes are prefixed with /api.
|
*/

// Health check endpoint for connectivity monitoring
Route::get('/health', fn () => response()->json(['status' => 'ok']));

// Public routes (no authentication required)
Route::post('/register', [\App\Http\Controllers\Auth\RegisterController::class, 'register']);
Route::post('/login', [\App\Http\Controllers\Auth\LoginController::class, 'login']);
Route::post('/forgot-password', [\App\Http\Controllers\Auth\ForgotPasswordController::class, 'sendResetLink']);

// Protected routes (require Sanctum token)
Route::middleware('auth:sanctum')->group(function () {
    // Auth
    Route::post('/logout', [\App\Http\Controllers\Auth\LogoutController::class, 'logout']);

    // Profile
    Route::get('/profile', [\App\Http\Controllers\ProfileController::class, 'show']);
    Route::post('/profile', [\App\Http\Controllers\ProfileController::class, 'store']);
    Route::put('/profile', [\App\Http\Controllers\ProfileController::class, 'update']);

    // User name update
    Route::put('/user/name', function (\Illuminate\Http\Request $request) {
        $request->validate([
            'first_name' => ['required', 'string', 'max:50'],
            'last_name' => ['required', 'string', 'max:50'],
        ]);
        $user = auth()->user();
        $user->update($request->only(['first_name', 'last_name']));
        return response()->json(['success' => true, 'data' => $user]);
    });

    // Exercises
    Route::get('/exercises', [\App\Http\Controllers\ExerciseController::class, 'index']);
    Route::get('/exercises/{exercise}', [\App\Http\Controllers\ExerciseController::class, 'show']);

    // Recommendations
    Route::post('/recommendations/generate', [\App\Http\Controllers\RecommendationController::class, 'generate']);
    Route::get('/recommendations/current', [\App\Http\Controllers\RecommendationController::class, 'current']);

    // Workout Sessions
    Route::post('/sessions', [\App\Http\Controllers\WorkoutSessionController::class, 'store']);
    Route::patch('/sessions/{session}/pause', [\App\Http\Controllers\WorkoutSessionController::class, 'pause']);
    Route::patch('/sessions/{session}/resume', [\App\Http\Controllers\WorkoutSessionController::class, 'resume']);
    Route::patch('/sessions/{session}/skip-exercise', [\App\Http\Controllers\WorkoutSessionController::class, 'skipExercise']);
    Route::patch('/sessions/{session}/complete', [\App\Http\Controllers\WorkoutSessionController::class, 'complete']);

    // Progress
    Route::get('/progress/summary', [\App\Http\Controllers\ProgressController::class, 'summary']);
    Route::get('/progress/history', [\App\Http\Controllers\ProgressController::class, 'history']);
    Route::get('/progress/weekly-stats', [\App\Http\Controllers\ProgressController::class, 'weeklyStats']);

    // Device Tokens
    Route::post('/device-tokens', [\App\Http\Controllers\DeviceTokenController::class, 'store']);
});
