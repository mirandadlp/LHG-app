<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Staircase extends Model
{
    protected $guarded = ['id'];

    protected function casts(): array
    {
        return ['width' => 'float'];
    }

    public function property(): BelongsTo
    {
        return $this->belongsTo(Property::class);
    }
}
