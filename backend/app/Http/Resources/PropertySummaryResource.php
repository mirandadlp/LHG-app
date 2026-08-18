<?php

namespace App\Http\Resources;

use App\Models\Property;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The lightweight shape used by list screens: directory cards, search results,
 * the approvals queue. Everything a card renders, nothing it doesn't.
 *
 * @mixin Property
 */
class PropertySummaryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        /** @var Property $property */
        $property = $this->resource;

        return [
            'id' => $property->id,
            'publicId' => $property->public_id,
            'siteName' => $property->site_name,
            'propertyName' => $property->property_name,
            'address' => $property->fullAddress(),
            'borough' => $property->borough,
            'council' => $property->council,
            'region' => $property->region,
            'propertyType' => $property->property_type,
            'operationalStatus' => $property->operational_status,
            'manager' => $property->manager_name,
            'managerEmail' => $property->manager_email,
            'verification' => $property->verification_status,
            'totalUnits' => $property->totalUnits(),
            'elevatorCount' => $property->elevators->count(),
            'staircaseCount' => $property->staircases->count(),
            'documentCount' => $property->documents->count(),
            'floors' => $property->floors,
            'accessibleBedroomCount' => $property->accessible_bedroom_count,
            'stepFree' => $property->step_free,
            'completeness' => $property->completeness(),
            'openFlagCount' => $property->changeFlags->where('resolution', 'Pending')->count(),
            'lastUpdated' => $property->changeLogs->first()?->created_at?->format('Y-m-d H:i'),
            'updatedAt' => $property->updated_at?->toIso8601String(),
        ];
    }
}
