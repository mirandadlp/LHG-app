<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ChangeFlag extends Model
{
    public const PENDING = 'Pending';

    public const CONFIRMED = 'Confirmed';

    public const REVERTED = 'Reverted';

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'previous_value' => 'integer',
            'new_value' => 'integer',
            'resolved_at' => 'datetime',
        ];
    }

    public function property(): BelongsTo
    {
        return $this->belongsTo(Property::class);
    }
}
