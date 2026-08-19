<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    /**
     * Demo accounts matching the roles in the original prototype. The password
     * for every seeded account is `password` — change these before the app
     * touches real data.
     */
    public const ACCOUNTS = [
        [
            'name' => 'Priya Raman',
            'email' => 'priya.raman@londonhotelgroup.co.uk',
            'role' => User::ROLE_ADMIN,
            'job_title' => 'Corporate Administrator',
        ],
        [
            'name' => 'Meher N.',
            'email' => 'meher.n@londonhotelgroup.co.uk',
            'role' => User::ROLE_LEADERSHIP,
            'job_title' => 'Leadership',
        ],
        [
            'name' => 'Jane Smith',
            'email' => 'jane.smith@londonhotelgroup.co.uk',
            'role' => User::ROLE_MANAGER,
            'phone' => '020 7946 0112',
            'job_title' => 'Property Manager',
        ],
        [
            'name' => 'David Okafor',
            'email' => 'david.okafor@londonhotelgroup.co.uk',
            'role' => User::ROLE_MANAGER,
            'phone' => '020 7946 0187',
            'job_title' => 'Property Manager',
        ],
        [
            'name' => 'Aisha Khan',
            'email' => 'aisha.khan@londonhotelgroup.co.uk',
            'role' => User::ROLE_MANAGER,
            'phone' => '020 7946 0233',
            'job_title' => 'Property Manager',
        ],
        [
            'name' => 'Tom Reilly',
            'email' => 'tom.reilly@londonhotelgroup.co.uk',
            'role' => User::ROLE_MANAGER,
            'phone' => '020 7946 0301',
            'job_title' => 'Property Manager',
        ],
        [
            'name' => 'Marta Nowak',
            'email' => 'marta.nowak@londonhotelgroup.co.uk',
            'role' => User::ROLE_MANAGER,
            'job_title' => 'Property Manager',
        ],
        [
            'name' => 'Sam Whitfield',
            'email' => 'sam.whitfield@londonhotelgroup.co.uk',
            'role' => User::ROLE_MANAGER,
            'job_title' => 'Property Manager',
        ],
    ];

    public function run(): void
    {
        foreach (self::ACCOUNTS as $account) {
            $user = User::firstOrNew(['email' => $account['email']]);

            $user->fill([
                ...$account,
                'password' => Hash::make('password'),
                'is_active' => true,
            ]);

            // Not fillable, so it has to be set directly.
            $user->email_verified_at = now();
            $user->save();
        }
    }
}
