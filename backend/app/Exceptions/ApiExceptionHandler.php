<?php

namespace App\Exceptions;

use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Throwable;

class ApiExceptionHandler
{
    /**
     * Handle an exception and return a consistent JSON response envelope.
     *
     * Success envelope: {"success": true, "data": <payload>, "message": <string|null>}
     * Error envelope:   {"success": false, "message": <string>, "errors": <object|null>}
     */
    public function handle(Throwable $e, Request $request): JsonResponse
    {
        return match (true) {
            $e instanceof ValidationException => $this->handleValidation($e),
            $e instanceof AuthenticationException => $this->handleAuthentication($e),
            $e instanceof ModelNotFoundException => $this->handleModelNotFound($e),
            $e instanceof NotFoundHttpException => $this->handleNotFound($e),
            $e instanceof HttpException => $this->handleHttpException($e),
            default => $this->handleGenericException($e),
        };
    }

    /**
     * Handle validation exceptions (422).
     * Maps errors to field → messages format.
     */
    protected function handleValidation(ValidationException $e): JsonResponse
    {
        return new JsonResponse([
            'success' => false,
            'message' => $e->getMessage(),
            'errors' => $e->errors(),
        ], Response::HTTP_UNPROCESSABLE_ENTITY, [
            'Content-Type' => 'application/json',
        ]);
    }

    /**
     * Handle authentication exceptions (401).
     */
    protected function handleAuthentication(AuthenticationException $e): JsonResponse
    {
        return new JsonResponse([
            'success' => false,
            'message' => 'Unauthenticated.',
            'errors' => null,
        ], Response::HTTP_UNAUTHORIZED, [
            'Content-Type' => 'application/json',
        ]);
    }

    /**
     * Handle model not found exceptions (404).
     */
    protected function handleModelNotFound(ModelNotFoundException $e): JsonResponse
    {
        $model = class_basename($e->getModel());

        return new JsonResponse([
            'success' => false,
            'message' => "{$model} not found.",
            'errors' => null,
        ], Response::HTTP_NOT_FOUND, [
            'Content-Type' => 'application/json',
        ]);
    }

    /**
     * Handle generic not found exceptions (404).
     */
    protected function handleNotFound(NotFoundHttpException $e): JsonResponse
    {
        return new JsonResponse([
            'success' => false,
            'message' => 'Resource not found.',
            'errors' => null,
        ], Response::HTTP_NOT_FOUND, [
            'Content-Type' => 'application/json',
        ]);
    }

    /**
     * Handle Symfony HTTP exceptions (403, 405, 429, etc.).
     */
    protected function handleHttpException(HttpException $e): JsonResponse
    {
        return new JsonResponse([
            'success' => false,
            'message' => $e->getMessage() ?: Response::$statusTexts[$e->getStatusCode()] ?? 'Error',
            'errors' => null,
        ], $e->getStatusCode(), [
            'Content-Type' => 'application/json',
        ]);
    }

    /**
     * Handle all other unhandled exceptions (500).
     * Never exposes stack traces or internal details to clients.
     */
    protected function handleGenericException(Throwable $e): JsonResponse
    {
        // Log the full exception server-side for debugging
        report($e);

        return new JsonResponse([
            'success' => false,
            'message' => 'An unexpected error occurred.',
            'errors' => null,
        ], Response::HTTP_INTERNAL_SERVER_ERROR, [
            'Content-Type' => 'application/json',
        ]);
    }
}
