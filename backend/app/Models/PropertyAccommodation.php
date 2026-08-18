<?php

namespace App\Models;

use App\Support\AccommodationRegistry;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PropertyAccommodation extends Model
{
    protected $guarded = ['id'];

    public function property(): BelongsTo
    {
        return $this->belongsTo(Property::class);
    }

    /** Blank counts as zero, exactly as the totals in the original app did. */
    public function count(string $key): int
    {
        $column = AccommodationRegistry::column($key);

        return $column ? (int) ($this->{$column} ?? 0) : 0;
    }

    public function total(): int
    {
        return $this->sumOf(AccommodationRegistry::keys());
    }

    /** @param array<int, string> $keys */
    public function sumOf(array $keys): int
    {
        return array_sum(array_map(fn ($key) => $this->count($key), $keys));
    }

    /** @return array<string, int|null> keyed by client key, preserving nulls */
    public function toBag(): array
    {
        $bag = [];

        foreach (AccommodationRegistry::columnMap() as $key => $column) {
            $value = $this->{$column};
            $bag[$key] = $value === null ? null : (int) $value;
        }

        return $bag;
    }
}
