<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    public const ROLE_ADMIN = 'admin';

    public const ROLE_MANAGER = 'manager';

    public const ROLE_LEADERSHIP = 'leadership';

    protected $fillable = [
        'name', 'email', 'password', 'role', 'phone', 'job_title', 'is_active',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    /** Properties this user is the named manager for. */
    public function properties(): HasMany
    {
        return $this->hasMany(Property::class, 'manager_id');
    }

    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    public function isManager(): bool
    {
        return $this->role === self::ROLE_MANAGER;
    }

    public function isLeadership(): bool
    {
        return $this->role === self::ROLE_LEADERSHIP;
    }

    /** Leadership is read-only; everyone else may write something. */
    public function canWrite(): bool
    {
        return ! $this->isLeadership();
    }

    /**
     * The label the original app displayed for each role. Kept so the iOS
     * client can show the same wording without hardcoding a mapping.
     */
    public function roleLabel(): string
    {
        return match ($this->role) {
            self::ROLE_ADMIN => 'Corporate Administrator',
            self::ROLE_MANAGER => 'Property Manager',
            default => 'Leadership',
        };
    }
}
