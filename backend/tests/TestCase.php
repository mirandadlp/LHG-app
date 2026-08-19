<?php

namespace Tests;

use App\Models\FieldDefinition;
use App\Models\Property;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Laravel\Sanctum\Sanctum;

abstract class TestCase extends BaseTestCase
{
    /**
     * Every test class that refreshes the database gets the seeded portfolio.
     *
     * This lives here rather than on each class deliberately. RefreshDatabase
     * passes --seed to a `migrate:fresh` that runs once for the entire suite,
     * so whichever class happens to run first decides for all of them. One
     * class quietly disagreeing leaves the rest querying an empty database,
     * and the errors appear nowhere near the class that caused them.
     */
    protected $seed = true;

    protected $seeder = DatabaseSeeder::class;

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
