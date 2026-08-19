<?php

namespace App\Console\Commands;

use App\Models\User;
use Database\Seeders\UserSeeder;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;

/**
 * Creates the first real account on a fresh install.
 *
 * The seeder exists for demos and gives every account the password `password`,
 * which must never reach a public host. This is the production path: it prompts
 * for a password without echoing it, enforces a length floor, and refuses to
 * quietly overwrite somebody who already exists.
 */
class CreateAdminCommand extends Command
{
    protected $signature = 'hub:create-admin
                            {--name= : Full name, as it appears on records}
                            {--email= : Sign-in address}
                            {--role=admin : admin, manager or leadership}';

    protected $description = 'Create an administrator account for the property hub';

    public function handle(): int
    {
        $name = $this->option('name') ?: $this->ask('Full name');
        $email = $this->option('email') ?: $this->ask('Email address');
        $role = $this->option('role');

        // Never accepted as an argument: a password on the command line lands in
        // the shell history and in the process list.
        $password = $this->secret('Password (at least 12 characters)');
        $confirmation = $this->secret('Confirm password');

        $validator = Validator::make([
            'name' => $name,
            'email' => $email,
            'role' => $role,
            'password' => $password,
            'password_confirmation' => $confirmation,
        ], [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'unique:users,email'],
            'role' => ['required', 'in:admin,manager,leadership'],
            'password' => ['required', 'confirmed', Password::min(12)],
        ]);

        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $message) {
                $this->components->error($message);
            }

            return self::FAILURE;
        }

        $user = new User([
            'name' => $name,
            'email' => $email,
            'role' => $role,
            'password' => $password,
            'is_active' => true,
        ]);

        // Guarded rather than fillable: an account an administrator creates at
        // the console is verified by definition, but nothing arriving over HTTP
        // should ever be able to set this.
        $user->email_verified_at = now();
        $user->save();

        $this->components->info("Created {$user->name} <{$user->email}> as {$user->roleLabel()}.");

        if ($this->seededDemoAccountsExist()) {
            $this->newLine();
            $this->components->warn(
                'Demo accounts from the seeder are present and all share the password "password". '
                .'Run `php artisan hub:disable-demo-accounts` before this host is reachable.'
            );
        }

        return self::SUCCESS;
    }

    private function seededDemoAccountsExist(): bool
    {
        return User::whereIn('email', array_column(UserSeeder::ACCOUNTS, 'email'))->exists();
    }
}
