<?php

namespace App\Http\Resources;

use App\Models\PropertyDocument;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin PropertyDocument */
class DocumentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'type' => $this->type,
            'date' => $this->created_at?->format('Y-m-d'),
            'by' => $this->uploaded_by_name,
            'notes' => $this->notes ?? '',
            'sizeBytes' => $this->size_bytes,
            'mimeType' => $this->mime_type,
            'downloadUrl' => route('documents.download', ['document' => $this->id]),
        ];
    }
}
