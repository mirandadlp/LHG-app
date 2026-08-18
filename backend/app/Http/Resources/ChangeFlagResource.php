<?php

namespace App\Http\Resources;

use App\Models\ChangeFlag;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ChangeFlag */
class ChangeFlagResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'key' => $this->accommodation_key,
            'label' => $this->label,
            'prev' => $this->previous_value,
            'next' => $this->new_value,
            'resolution' => $this->resolution,
            'raisedAt' => $this->created_at?->toIso8601String(),
        ];
    }
}
