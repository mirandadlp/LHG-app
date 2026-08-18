<?php

namespace App\Support;

/**
 * The accommodation model: fourteen unit types in four groups. Totals are always
 * the sum of every type — a blank count is treated as zero, never as unknown.
 */
final class AccommodationRegistry
{
    public const GROUPS = ['Rooms', 'Flats', 'Houses', 'Other'];

    /** client key => [label, group, column] */
    public const TYPES = [
        'singles' => ['Singles', 'Rooms', 'singles'],
        'doubles' => ['Doubles', 'Rooms', 'doubles'],
        'triples' => ['Triples', 'Rooms', 'triples'],
        'wcSc' => ['Water Closet SC Units', 'Rooms', 'wc_sc'],
        'flat1' => ['1 Bedroom Flats', 'Flats', 'flat1'],
        'flat2' => ['2 Bedroom Flats', 'Flats', 'flat2'],
        'flat3' => ['3 Bedroom Flats', 'Flats', 'flat3'],
        'wcFlats' => ['WC Flats', 'Flats', 'wc_flats'],
        'house2' => ['2 Bedroom Houses', 'Houses', 'house2'],
        'house3' => ['3 Bedroom Houses', 'Houses', 'house3'],
        'house4' => ['4 Bedroom Houses', 'Houses', 'house4'],
        'house5' => ['5 Bedroom Houses', 'Houses', 'house5'],
        'wcHouses' => ['WC Houses', 'Houses', 'wc_houses'],
        'other' => ['Other Accommodation Type', 'Other', 'other'],
    ];

    public const ROOM_KEYS = ['singles', 'doubles', 'triples', 'wcSc'];

    public const FLAT_KEYS = ['flat1', 'flat2', 'flat3', 'wcFlats'];

    public const HOUSE_KEYS = ['house2', 'house3', 'house4', 'house5', 'wcHouses'];

    public static function keys(): array
    {
        return array_keys(self::TYPES);
    }

    public static function label(string $key): string
    {
        return self::TYPES[$key][0] ?? $key;
    }

    public static function group(string $key): string
    {
        return self::TYPES[$key][1] ?? 'Other';
    }

    public static function column(string $key): ?string
    {
        return self::TYPES[$key][2] ?? null;
    }

    /** @return array<string, string> client key => db column */
    public static function columnMap(): array
    {
        return array_map(fn ($t) => $t[2], self::TYPES);
    }

    /** Descriptor list for the client, so the app never hardcodes the model. */
    public static function descriptors(): array
    {
        return array_map(
            fn ($key) => [
                'key' => $key,
                'label' => self::label($key),
                'group' => self::group($key),
            ],
            self::keys()
        );
    }

    /**
     * A change is "large" when a count moves by at least 10 units AND by at
     * least half of its previous value. Growth from zero is never flagged —
     * that is a first-time entry, not a suspicious correction.
     */
    public static function isLargeChange(int $previous, int $next): bool
    {
        if ($previous <= 0) {
            return false;
        }

        $delta = abs($next - $previous);

        return $delta >= 10 && ($delta / $previous) >= 0.5;
    }
}
