<?php

namespace App\Traits;

use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

/**
 * Trait providing consistent API response formatting.
 *
 * All responses follow the envelope format:
 * - Success: {"success": true, "data": <payload>, "message": <string|null>}
 * - Error:   {"success": false, "message": <string>, "errors": <object|null>}
 */
trait ApiResponses
{
    /**
     * Return a successful JSON response (HTTP 200).
     */
    protected function successResponse(mixed $data = null, ?string $message = null, int $status = Response::HTTP_OK): JsonResponse
    {
        return new JsonResponse([
            'success' => true,
            'data' => $data,
            'message' => $message,
        ], $status, [
            'Content-Type' => 'application/json',
        ]);
    }

    /**
     * Return a successful created JSON response (HTTP 201).
     */
    protected function createdResponse(mixed $data = null, ?string $message = null): JsonResponse
    {
        return $this->successResponse($data, $message, Response::HTTP_CREATED);
    }

    /**
     * Return an error JSON response.
     */
    protected function errorResponse(string $message, int $status = Response::HTTP_BAD_REQUEST, ?array $errors = null): JsonResponse
    {
        return new JsonResponse([
            'success' => false,
            'message' => $message,
            'errors' => $errors,
        ], $status, [
            'Content-Type' => 'application/json',
        ]);
    }
}
