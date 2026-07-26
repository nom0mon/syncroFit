<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ForceJsonResponse
{
    /**
     * Handle an incoming request.
     *
     * Ensures that all API requests expect JSON responses and all responses
     * have the correct Content-Type header.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Force the request to expect JSON
        $request->headers->set('Accept', 'application/json');

        $response = $next($request);

        // Ensure Content-Type is application/json for all API responses
        $response->headers->set('Content-Type', 'application/json');

        return $response;
    }
}
