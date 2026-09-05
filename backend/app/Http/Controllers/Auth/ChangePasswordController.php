<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use Illuminate\Http\JsonResponse;

class ChangePasswordController extends Controller
{
    /**
     * Change the authenticated user's password.
     *
     * Persists the new password (hashed via the User model cast) and revokes
     * every other Sanctum token, leaving only the current request's token valid.
     */
    public function update(ChangePasswordRequest $request): JsonResponse
    {
        $user = $request->user();

        $user->password = $request->validated('new_password');
        $user->save();

        // Revoke all other tokens, keeping the current access token valid.
        $user->tokens()
            ->where('id', '!=', $user->currentAccessToken()->getKey())
            ->delete();

        return $this->successResponse(null, 'Password changed successfully.');
    }
}
