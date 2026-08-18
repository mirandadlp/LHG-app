<?php

namespace Tests;

use App\Models\FieldDefinition;
use App\Models\Property;
use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Laravel\Sanctum\Sanctum;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // The registry is memoised per request; tests span many, so reset it.
        FieldDefinition::forgetCache();
    }

    protected function admin(): User
    {
        return User::where('role', User::ROLE_ADMIN)->firstOrFail();
    }

    protected function leadership(): User
    {
        return User::where('role', User::ROLE_LEADERSHIP)->firstOrFail();
    }

    /** Jane Smith manages Croydon Housing in the seeded portfolio. */
    protected function manager(string $email = 'jane.smith@londonhotelgroup.co.uk'): User
    {
        return User::where('email', $email)->firstOrFail();
    }

    protected function croydon(): Property
    {
        return Property::where('site_name', 'Croydon Housing')->firstOrFail();
    }

    protected function actingAsUser(User $user): static
    {
        Sanctum::actingAs($user);

        return $this;
    }
}
