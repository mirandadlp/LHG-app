<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin User */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role,
            'roleLabel' => $this->roleLabel(),
            'phone' => $this->phone,
            'jobTitle' => $this->job_title,
            'initials' => collect(explode(' ', $this->name))
                ->map(fn ($word) => mb_substr($word, 0, 1))
                ->take(2)
                ->join(''),
            'permissions' => [
                'canCreateProperties' => $this->isAdmin(),
                'canReview' => $this->isAdmin(),
                'canImport' => $this->isAdmin(),
                'canManageFields' => $this->isAdmin(),
                'canEdit' => $this->canWrite(),
            ],
        ];
    }
}
