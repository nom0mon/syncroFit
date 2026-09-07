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

    // Legacy user identity update
    Route::put('/user/name', function (\Illuminate\Http\Request $request) {
        $request->merge(['username' => strtolower(trim((string) $request->input('username', auth()->user()->username)))]);
        $validated = $request->validate([
            'first_name' => ['required', 'string'],
            'last_name' => ['required', 'string'],
            'username' => ['required', 'string', 'min:3', 'max:30', 'regex:/^[a-z0-9._]+$/', \Illuminate\Validation\Rule::unique('users', 'username')->ignore(auth()->id())],
        ]);
        $user = auth()->user();
        $user->update($validated);
        return response()->json(['success' => true, 'data' => $user]);
    });

    // Change password
    Route::put('/user/password', [\App\Http\Controllers\Auth\ChangePasswordController::class, 'update']);

    // Exercises
    Route::get('/exercises', [\App\Http\Controllers\ExerciseController::class, 'index']);
    Route::get('/exercises/{exercise}', [\App\Http\Controllers\ExerciseController::class, 'show']);

    // Workouts
    Route::get('/workouts', [\App\Http\Controllers\WorkoutController::class, 'index']);
    Route::post('/workouts', [\App\Http\Controllers\WorkoutController::class, 'store']);
    Route::post('/workouts/generate', [\App\Http\Controllers\WorkoutController::class, 'generate']);
    Route::post('/workouts/plans/{planId}/accept', [\App\Http\Controllers\WorkoutController::class, 'acceptPlan']);
    Route::get('/workouts/generated', [\App\Http\Controllers\WorkoutController::class, 'generated']);
    Route::put('/workouts/{workout}/exercises', [\App\Http\Controllers\WorkoutController::class, 'customize']);

    // Workout History
    Route::post('/workout-history', [\App\Http\Controllers\WorkoutHistoryController::class, 'store']);
    Route::get('/workout-history', [\App\Http\Controllers\WorkoutHistoryController::class, 'index']);
    Route::get('/workout-history/stats', [\App\Http\Controllers\WorkoutHistoryController::class, 'stats']);

    // Private progress logs
    Route::get('/progress-logs', [\App\Http\Controllers\ProgressLogController::class, 'index']);
    Route::post('/progress-logs', [\App\Http\Controllers\ProgressLogController::class, 'store']);
    Route::get('/progress-logs/{progressLog}', [\App\Http\Controllers\ProgressLogController::class, 'show']);
    Route::get('/progress-logs/{progressLog}/image', [\App\Http\Controllers\ProgressLogController::class, 'image']);
    Route::delete('/progress-logs/{progressLog}', [\App\Http\Controllers\ProgressLogController::class, 'destroy']);

    // Community
    Route::get('/community/posts', [\App\Http\Controllers\CommunityController::class, 'index']);
    Route::post('/community/posts', [\App\Http\Controllers\CommunityController::class, 'store']);
    Route::get('/community/posts/{post}', [\App\Http\Controllers\CommunityController::class, 'show']);
    Route::delete('/community/posts/{post}', [\App\Http\Controllers\CommunityController::class, 'destroy']);
    Route::put('/community/posts/{post}/like', [\App\Http\Controllers\CommunityController::class, 'like']);
    Route::delete('/community/posts/{post}/like', [\App\Http\Controllers\CommunityController::class, 'unlike']);
    Route::get('/community/posts/{post}/comments', [\App\Http\Controllers\CommunityController::class, 'comments']);
    Route::post('/community/posts/{post}/comments', [\App\Http\Controllers\CommunityController::class, 'comment']);
    Route::delete('/community/posts/{post}/comments/{comment}', [\App\Http\Controllers\CommunityController::class, 'destroyComment']);
    Route::get('/community/posts/{post}/media/{media}', [\App\Http\Controllers\CommunityController::class, 'media']);
});
