<?php

namespace App\Http\Resources;

use App\Models\ChangeLog;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ChangeLog */
class ChangeLogResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'field' => $this->field,
            'prev' => $this->previous_value ?? '—',
            'next' => $this->new_value ?? '—',
            'by' => $this->changed_by_name ?? 'System',
            'date' => $this->created_at?->format('Y-m-d H:i'),
            'reason' => $this->reason,
            'approval' => $this->approval_status,
        ];
    }
}
