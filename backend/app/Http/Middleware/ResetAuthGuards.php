<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class ResetAuthGuards
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        return $next($request);
    }

    /**
     * Forget any resolved authentication guards after the response is sent.
     *
     * A request that authenticates with a real bearer token must re-resolve
     * that token on every request rather than reusing a user that an earlier
     * request cached on the guard. Without this, when the application container
     * is reused across requests (for example in the test harness), a guard that
     * resolved a user on an earlier request keeps returning that user even after
     * the underlying token has been revoked. This is a no-op in production,
     * where each request already runs in a fresh process.
     *
     * The reset is limited to requests that carry a bearer token so that it
     * never disturbs guards whose user was set directly (for example by the
     * test acting-as helper, which does not send an Authorization header).
     */
    public function terminate(Request $request, Response $response): void
    {
        if ($request->bearerToken() !== null) {
            Auth::forgetGuards();
        }
    }
}
