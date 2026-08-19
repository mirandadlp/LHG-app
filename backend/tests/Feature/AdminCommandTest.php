<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\UserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * The commands that stand between a demo database and a production one.
 */
class AdminCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_an_administrator(): void
    {
        $this->artisan('hub:create-admin', [
            '--name' => 'Miranda De La Paz',
            '--email' => 'miranda@example.com',
        ])
            ->expectsQuestion('Password (at least 12 characters)', 'a-properly-long-password')
            ->expectsQuestion('Confirm password', 'a-properly-long-password')
            ->assertSuccessful();

        $user = User::where('email', 'miranda@example.com')->firstOrFail();

        $this->assertSame(User::ROLE_ADMIN, $user->role);
        $this->assertTrue($user->is_active);
        $this->assertNotNull($user->email_verified_at);

        // Stored hashed, never in the clear.
        $this->assertNotSame('a-properly-long-password', $user->password);
        $this->assertTrue(Hash::check('a-properly-long-password', $user->password));
    }

    public function test_the_new_account_can_actually_sign_in(): void
    {
        $this->artisan('hub:create-admin', [
            '--name' => 'Miranda De La Paz',
            '--email' => 'miranda@example.com',
        ])
            ->expectsQuestion('Password (at least 12 characters)', 'a-properly-long-password')
            ->expectsQuestion('Confirm password', 'a-properly-long-password')
            ->assertSuccessful();

        $this->postJson('/api/auth/login', [
            'email' => 'miranda@example.com',
            'password' => 'a-properly-long-password',
        ])->assertOk()->assertJsonPath('user.role', 'admin');
    }

    public function test_a_short_password_is_refused(): void
    {
        $this->artisan('hub:create-admin', [
            '--name' => 'Too Short',
            '--email' => 'short@example.com',
        ])
            ->expectsQuestion('Password (at least 12 characters)', 'short')
            ->expectsQuestion('Confirm password', 'short')
            ->assertFailed();

        $this->assertDatabaseMissing('users', ['email' => 'short@example.com']);
    }

    public function test_a_mismatched_confirmation_is_refused(): void
    {
        $this->artisan('hub:create-admin', [
            '--name' => 'Mismatch',
            '--email' => 'mismatch@example.com',
        ])
            ->expectsQuestion('Password (at least 12 characters)', 'a-properly-long-password')
            ->expectsQuestion('Confirm password', 'a-different-long-password')
            ->assertFailed();

        $this->assertDatabaseMissing('users', ['email' => 'mismatch@example.com']);
    }

    public function test_it_will_not_overwrite_an_existing_account(): void
    {
        $this->artisan('hub:create-admin', [
            '--name' => 'Impostor',
            '--email' => 'priya.raman@londonhotelgroup.co.uk',
        ])
            ->expectsQuestion('Password (at least 12 characters)', 'a-properly-long-password')
            ->expectsQuestion('Confirm password', 'a-properly-long-password')
            ->assertFailed();

        $this->assertSame(
            'Priya Raman',
            User::where('email', 'priya.raman@londonhotelgroup.co.uk')->value('name'),
        );
    }

    public function test_demo_accounts_are_deactivated_and_can_no_longer_sign_in(): void
    {
        // The password every seeded account ships with.
        $this->postJson('/api/auth/login', [
            'email' => 'jane.smith@londonhotelgroup.co.uk',
            'password' => 'password',
        ])->assertOk();

        $this->artisan('hub:disable-demo-accounts')
            ->expectsConfirmation('Continue?', 'yes')
            ->assertSuccessful();

        $this->app['auth']->forgetGuards();

        $this->postJson('/api/auth/login', [
            'email' => 'jane.smith@londonhotelgroup.co.uk',
            'password' => 'password',
        ])->assertStatus(422);

        $this->assertFalse(
            (bool) User::where('email', 'jane.smith@londonhotelgroup.co.uk')->value('is_active')
        );
    }

    public function test_disabling_demo_accounts_revokes_their_tokens(): void
    {
        $token = $this->postJson('/api/auth/login', [
            'email' => 'jane.smith@londonhotelgroup.co.uk',
            'password' => 'password',
        ])->json('token');

        $this->artisan('hub:disable-demo-accounts')
            ->expectsConfirmation('Continue?', 'yes')
            ->assertSuccessful();

        $this->app['auth']->forgetGuards();

        // A token issued before the lockout must stop working too, or the
        // deactivation only closes the front door.
        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/auth/me')
            ->assertUnauthorized();
    }

    public function test_the_property_data_survives_deactivation(): void
    {
        $this->artisan('hub:disable-demo-accounts')
            ->expectsConfirmation('Continue?', 'yes')
            ->assertSuccessful();

        $this->assertDatabaseCount('properties', 7);
    }

    public function test_it_is_a_no_op_when_no_demo_accounts_are_present(): void
    {
        User::whereIn('email', array_column(UserSeeder::ACCOUNTS, 'email'))->forceDelete();

        $this->artisan('hub:disable-demo-accounts')
            ->expectsOutputToContain('No seeded demo accounts are present.')
            ->assertSuccessful();
    }
}
