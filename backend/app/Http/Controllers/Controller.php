<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

abstract class Controller
{
    /**
     * Return a successful JSON response in the standard envelope.
     *
     * {"success": true, "data": <payload>, "message": <string|null>}
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
     * Return a created (201) JSON response in the standard envelope.
     */
    protected function createdResponse(mixed $data = null, ?string $message = null): JsonResponse
    {
        return $this->successResponse($data, $message, Response::HTTP_CREATED);
    }

    /**
     * Return an error JSON response in the standard envelope.
     *
     * {"success": false, "message": <string>, "errors": <object|null>}
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
