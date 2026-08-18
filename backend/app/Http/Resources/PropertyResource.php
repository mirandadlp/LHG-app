<?php

namespace App\Http\Resources;

use App\Models\Property;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The full property record: every field value, the accommodation bag, lifts,
 * stairs, documents, audit history and any open change flags.
 *
 * @mixin Property
 */
class PropertyResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        /** @var Property $property */
        $property = $this->resource;

        $missing = $property->missingFields();

        return [
            'id' => $property->id,
            'publicId' => $property->public_id,
            'verification' => $property->verification_status,
            'submittedAt' => $property->submitted_at?->toIso8601String(),
            'verifiedAt' => $property->verified_at?->toIso8601String(),
            'verificationDueOn' => $property->verification_due_on?->format('Y-m-d'),

            // Keyed by field key — the exact shape the client renders from.
            'values' => $property->fieldValueBag(),

            'accommodation' => $property->accommodation?->toBag() ?? [],
            'totalUnits' => $property->totalUnits(),
            'flatsTotal' => $property->flatsTotal(),
            'housesTotal' => $property->housesTotal(),

            'elevators' => ElevatorResource::collection($property->elevators),
            'staircases' => StaircaseResource::collection($property->staircases),
            'documents' => DocumentResource::collection($property->documents),
            'history' => ChangeLogResource::collection($property->changeLogs),
            'flags' => ChangeFlagResource::collection(
                $property->changeFlags->where('resolution', 'Pending')->values()
            ),

            'completeness' => $property->completeness(),
            'missing' => [
                'required' => $missing['required'],
                'optional' => $missing['optional'],
            ],
            'pendingApprovalCount' => $property->changeLogs->where('approval_status', 'Pending')->count(),

            'permissions' => [
                'canEdit' => $request->user()?->can('update', $property) ?? false,
                'canSubmit' => $request->user()?->can('submit', $property) ?? false,
                'canReview' => $request->user()?->can('review', $property) ?? false,
                'canDelete' => $request->user()?->can('delete', $property) ?? false,
            ],

            'createdAt' => $property->created_at?->toIso8601String(),
            'updatedAt' => $property->updated_at?->toIso8601String(),
        ];
    }
}
