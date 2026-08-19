<?php

namespace App\Console\Commands;

use App\Models\User;
use Database\Seeders\UserSeeder;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

/**
 * Takes the seeded demo accounts out of service.
 *
 * The seeder is genuinely useful — it gives you seven realistic properties to
 * click through — but every account it creates has the password `password`. On
 * anything reachable from the internet that is an open door. This closes it
 * without discarding the demo data those accounts are attached to.
 */
class DisableDemoAccountsCommand extends Command
{
    protected $signature = 'hub:disable-demo-accounts
                            {--delete : Remove the accounts outright instead of deactivating them}';

    protected $description = 'Deactivate or remove the demo accounts created by the seeder';

    public function handle(): int
    {
        $emails = array_column(UserSeeder::ACCOUNTS, 'email');
        $accounts = User::whereIn('email', $emails)->get();

        if ($accounts->isEmpty()) {
            $this->components->info('No seeded demo accounts are present.');

            return self::SUCCESS;
        }

        $this->components->warn("Found {$accounts->count()} demo accounts.");

        foreach ($accounts as $account) {
            $this->line("  · {$account->email}");
        }

        if (! $this->confirm('Continue?', true)) {
            return self::FAILURE;
        }

        if ($this->option('delete')) {
            // Properties reference their manager with nullOnDelete, so the
            // records survive; they simply lose the assignment.
            $count = User::whereIn('email', $emails)->delete();

            $this->components->info("Removed {$count} demo accounts. Reassign the affected properties.");

            return self::SUCCESS;
        }

        foreach ($accounts as $account) {
            $account->forceFill([
                'is_active' => false,
                // A deactivated account is refused at sign-in, but rotating the
                // password too means a later reactivation cannot resurrect the
                // known one.
                'password' => Str::random(48),
            ])->save();

            $account->tokens()->delete();
        }

        $this->components->info(
            "Deactivated {$accounts->count()} demo accounts and revoked their API tokens."
        );

        return self::SUCCESS;
    }
}
