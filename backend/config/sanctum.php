<?php

use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\ValidateCsrfToken;
use Laravel\Sanctum\Http\Middleware\AuthenticateSession;

return [
    /*
     | The iOS app talks to the API with bearer tokens, not cookies, so no
     | stateful domains are configured. The web client uses the same token flow.
     */
    'stateful' => explode(',', (string) env('SANCTUM_STATEFUL_DOMAINS', '')),

    'guard' => ['web'],

    /*
     | Minutes until an issued token expires. A signed-in property manager stays
     | signed in for 30 days by default, then has to authenticate again.
     */
    'expiration' => env('SANCTUM_TOKEN_EXPIRATION', 43200),

    'token_prefix' => env('SANCTUM_TOKEN_PREFIX', ''),

    'middleware' => [
        'authenticate_session' => AuthenticateSession::class,
        'encrypt_cookies' => EncryptCookies::class,
        'validate_csrf_token' => ValidateCsrfToken::class,
    ],
];
