<?php

use App\Http\Controllers\Auth\ResetPasswordController;
use Illuminate\Support\Facades\Route;

Route::get('/reset-password/{token}', [ResetPasswordController::class, 'create'])
    ->name('password.reset');
Route::post('/reset-password', [ResetPasswordController::class, 'store'])
    ->name('password.update');
Route::get('/password-reset-complete', [ResetPasswordController::class, 'complete'])
    ->name('password.reset.complete');
