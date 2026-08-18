<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PropertyFieldValue extends Model
{
    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'value_number' => 'float',
            'value_date' => 'date:Y-m-d',
        ];
    }

    public function property(): BelongsTo
    {
        return $this->belongsTo(Property::class);
    }

    public function fieldDefinition(): BelongsTo
    {
        return $this->belongsTo(FieldDefinition::class);
    }

    /** Read the value back in the shape the field's type implies. */
    public function typedValue(string $type): mixed
    {
        return match ($type) {
            'number' => $this->value_number === null ? null : (int) $this->value_number,
            'decimal' => $this->value_number === null ? null : (float) $this->value_number,
            'date' => $this->value_date?->format('Y-m-d'),
            'measurement' => $this->value_number === null
                ? null
                : ['v' => (float) $this->value_number, 'u' => $this->value_unit ?: 'm²'],
            default => $this->value_text,
        };
    }

    /** Write a client-supplied value into the right typed column. */
    public function fillTyped(string $type, mixed $value): static
    {
        $this->value_text = null;
        $this->value_number = null;
        $this->value_date = null;
        $this->value_unit = null;

        if ($value === null || $value === '') {
            return $this;
        }

        match ($type) {
            'number', 'decimal' => $this->value_number = (float) $value,
            'date' => $this->value_date = $value,
            'measurement' => (function () use ($value) {
                $this->value_number = isset($value['v']) && $value['v'] !== '' ? (float) $value['v'] : null;
                $this->value_unit = $value['u'] ?? 'm²';
            })(),
            default => $this->value_text = (string) $value,
        };

        return $this;
    }
}
