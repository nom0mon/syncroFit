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
     * Ensures that API requests expect JSON errors. Controllers remain free
     * to return images and other binary responses with their real MIME type.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Force the request to expect JSON
        $request->headers->set('Accept', 'application/json');

        return $next($request);
    }
}
