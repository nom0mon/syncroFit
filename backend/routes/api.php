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

    // Workouts
    Route::get('/workouts', [\App\Http\Controllers\WorkoutController::class, 'index']);
    Route::post('/workouts', [\App\Http\Controllers\WorkoutController::class, 'store']);
    Route::post('/workouts/generate', [\App\Http\Controllers\WorkoutController::class, 'generate']);
    Route::get('/workouts/generated', [\App\Http\Controllers\WorkoutController::class, 'generated']);

    // Workout History
    Route::post('/workout-history', [\App\Http\Controllers\WorkoutHistoryController::class, 'store']);
    Route::get('/workout-history', [\App\Http\Controllers\WorkoutHistoryController::class, 'index']);
    Route::get('/workout-history/stats', [\App\Http\Controllers\WorkoutHistoryController::class, 'stats']);
});
