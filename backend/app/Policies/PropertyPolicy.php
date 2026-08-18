<?php

namespace App\Policies;

use App\Models\Property;
use App\Models\User;

/**
 * Who may do what to a property record.
 *
 * The rules are the ones the business already worked to:
 *   · Corporate administrators do everything.
 *   · Property managers edit only the properties they are named on, and only
 *     until they submit — a submitted record is frozen pending review.
 *   · Leadership reads everything and writes nothing.
 */
class PropertyPolicy
{
    public function viewAny(User $user): bool
    {
        return true; // Scoped by Property::scopeVisibleTo.
    }

    public function view(User $user, Property $property): bool
    {
        return ! $user->isManager() || $this->managesProperty($user, $property);
    }

    public function create(User $user): bool
    {
        return $user->isAdmin();
    }

    public function update(User $user, Property $property): bool
    {
        if ($user->isAdmin()) {
            return true;
        }

        if (! $user->isManager() || ! $this->managesProperty($user, $property)) {
            return false;
        }

        // A submitted record is locked while corporate reviews it.
        return $property->verification_status !== Property::STATUS_SUBMITTED;
    }

    public function delete(User $user, Property $property): bool
    {
        return $user->isAdmin();
    }

    /** Submitting for review is the property manager's action (admins may too). */
    public function submit(User $user, Property $property): bool
    {
        if ($property->verification_status === Property::STATUS_SUBMITTED) {
            return false;
        }

        return $user->isAdmin() || ($user->isManager() && $this->managesProperty($user, $property));
    }

    /** Approving or rejecting a submission is corporate's decision alone. */
    public function review(User $user, Property $property): bool
    {
        return $user->isAdmin();
    }

    public function manageDocuments(User $user, Property $property): bool
    {
        return $this->update($user, $property);
    }

    public function export(User $user): bool
    {
        return true; // Everyone may export what they are allowed to see.
    }

    private function managesProperty(User $user, Property $property): bool
    {
        return $property->manager_id === $user->id
            || ($property->manager_email && $property->manager_email === $user->email);
    }
}
