<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OptionListItem extends Model
{
    protected $guarded = ['id'];

    /** All controlled lists, keyed the way the client expects them. */
    public static function grouped(): array
    {
        return static::query()
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->groupBy('list_key')
            ->map(fn ($items) => $items->pluck('value')->values()->all())
            ->all();
    }
}
