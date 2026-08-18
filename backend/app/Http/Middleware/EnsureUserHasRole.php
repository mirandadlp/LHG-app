<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Route-level role gate, e.g. ->middleware('role:admin').
 *
 * This is the coarse check. Anything finer — "may this manager touch this
 * property" — belongs in PropertyPolicy, not here.
 */
class EnsureUserHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user || ! in_array($user->role, $roles, true)) {
            return response()->json([
                'message' => 'Your role does not permit this action.',
            ], 403);
        }

        return $next($request);
    }
}
