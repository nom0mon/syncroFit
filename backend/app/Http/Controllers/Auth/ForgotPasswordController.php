<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Services\PasswordResetMailer;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\RateLimiter;

class ForgotPasswordController extends Controller
{
    /**
     * Handle a forgot-password request.
     *
     * Sends a password reset link if the email exists,
     * but always returns an identical 200 response (anti-enumeration).
     * Rate limited to 5 requests per email per 15 minutes.
     */
    public function sendResetLink(ForgotPasswordRequest $request, PasswordResetMailer $mailer): JsonResponse
    {
        $email = $request->validated()['email'];

        // Rate limiting: 5 requests per email per 15 minutes
        $rateLimitKey = 'forgot-password|' . strtolower($email);

        if (RateLimiter::tooManyAttempts($rateLimitKey, 5)) {
            return $this->errorResponse(
                'Too many requests. Please try again later.',
                429
            );
        }

        RateLimiter::hit($rateLimitKey, 15 * 60);

        // Attempt to send the reset link — we ignore the result
        // to always return the same response (anti-enumeration)
        try {
            $mailer->send($email);
        } catch (\Exception $e) {
            report($e);
            // Silently fail — anti-enumeration requires identical response
        }

        return $this->successResponse(
            null,
            'If an account with that email exists, a password reset link has been sent.'
        );
    }
}
