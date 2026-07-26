<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class LoginController extends Controller
{
    /**
     * Handle a login request.
     *
     * Authenticates credentials and issues a Sanctum token on success.
     * Returns a generic 401 for invalid credentials (anti-enumeration).
     */
    public function login(LoginRequest $request): JsonResponse
    {
        if (!Auth::attempt($request->only('email', 'password'))) {
            return $this->errorResponse(
                'Invalid email or password',
                Response::HTTP_UNAUTHORIZED
            );
        }

        $user = Auth::user();
        $token = $user->createToken('auth_token')->plainTextToken;

        return $this->successResponse([
            'user' => $user,
            'token' => $token,
        ], 'Login successful');
    }
}
