<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Elevator extends Model
{
    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'width' => 'float',
            'depth' => 'float',
            'height' => 'float',
            'door_width' => 'float',
        ];
    }

    public function property(): BelongsTo
    {
        return $this->belongsTo(Property::class);
    }
}
