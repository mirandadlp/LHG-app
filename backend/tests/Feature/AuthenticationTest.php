<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthenticationTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    protected $seeder = DatabaseSeeder::class;

    public function test_a_valid_login_returns_a_token_and_the_user(): void
    {
        $response = $this->postJson('/api/auth/login', [
            'email' => 'priya.raman@londonhotelgroup.co.uk',
            'password' => 'password',
            'deviceName' => 'iPhone 15',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['token', 'expiresAt', 'user' => ['id', 'name', 'role', 'roleLabel', 'permissions']])
            ->assertJsonPath('user.role', 'admin')
            ->assertJsonPath('user.roleLabel', 'Corporate Administrator');

        $this->assertNotEmpty($response->json('token'));
    }

    public function test_a_wrong_password_is_rejected(): void
    {
        $this->postJson('/api/auth/login', [
            'email' => 'priya.raman@londonhotelgroup.co.uk',
            'password' => 'not-the-password',
        ])->assertStatus(422)->assertJsonValidationErrors('email');
    }

    public function test_a_deactivated_account_cannot_sign_in(): void
    {
        User::where('email', 'jane.smith@londonhotelgroup.co.uk')->update(['is_active' => false]);

        $this->postJson('/api/auth/login', [
            'email' => 'jane.smith@londonhotelgroup.co.uk',
            'password' => 'password',
        ])->assertStatus(422);
    }

    public function test_repeated_failures_are_throttled(): void
    {
        foreach (range(1, 5) as $ignored) {
            $this->postJson('/api/auth/login', [
                'email' => 'priya.raman@londonhotelgroup.co.uk',
                'password' => 'wrong',
            ])->assertStatus(422);
        }

        // The sixth attempt is refused even with the right password.
        $this->postJson('/api/auth/login', [
            'email' => 'priya.raman@londonhotelgroup.co.uk',
            'password' => 'password',
        ])->assertStatus(429);
    }

    public function test_the_api_is_closed_without_a_token(): void
    {
        $this->getJson('/api/properties')->assertUnauthorized();
        $this->getJson('/api/dashboard')->assertUnauthorized();
        $this->getJson('/api/bootstrap')->assertUnauthorized();
    }

    public function test_signing_out_revokes_only_the_current_token(): void
    {
        $first = $this->postJson('/api/auth/login', [
            'email' => 'priya.raman@londonhotelgroup.co.uk',
            'password' => 'password',
            'deviceName' => 'iPhone',
        ])->json('token');

        $second = $this->postJson('/api/auth/login', [
            'email' => 'priya.raman@londonhotelgroup.co.uk',
            'password' => 'password',
            'deviceName' => 'iPad',
        ])->json('token');

        $this->withHeader('Authorization', "Bearer {$first}")
            ->postJson('/api/auth/logout')->assertOk();

        // Within one test the auth guard caches the user it already resolved,
        // which a real request never does — clear it so this asserts behaviour
        // rather than the harness.
        $this->app['auth']->forgetGuards();

        $this->withHeader('Authorization', "Bearer {$first}")
            ->getJson('/api/auth/me')->assertUnauthorized();

        $this->app['auth']->forgetGuards();

        $this->withHeader('Authorization', "Bearer {$second}")
            ->getJson('/api/auth/me')->assertOk();
    }

    public function test_bootstrap_returns_everything_the_app_needs_to_render(): void
    {
        $this->actingAsUser($this->admin());

        $this->getJson('/api/bootstrap')
            ->assertOk()
            ->assertJsonStructure([
                'user', 'sections', 'fields', 'options',
                'accommodationTypes', 'accommodationGroups',
                'verificationStatuses', 'reportColumns',
            ])
            ->assertJsonCount(14, 'accommodationTypes')
            ->assertJsonPath('options.boroughs.0', 'Croydon');
    }
}
