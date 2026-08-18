<?php

namespace App\Http\Resources;

use App\Models\Elevator;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Elevator */
class ElevatorResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name ?? '',
            'type' => $this->type,
            'capacity' => $this->capacity,
            'maxOccupancy' => $this->max_occupancy,
            'width' => $this->width,
            'depth' => $this->depth,
            'height' => $this->height,
            'doorWidth' => $this->door_width,
            'accessible' => $this->accessible,
            'service' => $this->service,
            'passenger' => $this->passenger,
            'notes' => $this->notes ?? '',
            'position' => $this->position,
        ];
    }
}
