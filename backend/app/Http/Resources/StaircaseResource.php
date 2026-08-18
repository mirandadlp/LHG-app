<?php

namespace App\Http\Resources;

use App\Models\Staircase;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Staircase */
class StaircaseResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name ?? '',
            'location' => $this->location ?? '',
            'floorsServed' => $this->floors_served,
            'width' => $this->width,
            'classification' => $this->classification,
            'emergencyExit' => $this->emergency_exit,
            'notes' => $this->notes ?? '',
            'position' => $this->position,
        ];
    }
}
