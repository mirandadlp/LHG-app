<?php

namespace App\Services;

use App\Models\Property;
use Illuminate\Support\Collection;

/**
 * Turns a set of properties into report rows. Every export format — CSV, Excel
 * and PDF — renders from this one method, so a figure can never differ between
 * the table on screen and the file that lands in someone's inbox.
 */
class ReportBuilder
{
    public const ALL_COLUMNS = [
        'Site', 'Address', 'Borough', 'Council', 'Region', 'Property type',
        'Singles', 'Doubles', 'Triples', 'WC SC units', 'Flats', 'Houses',
        'Total units', 'Elevators', 'Staircases', 'Accessible bedrooms',
        'Step-free entrance', 'Manager', 'Verification status',
        'Completeness %', 'Last updated',
    ];

    public const DEFAULT_COLUMNS = [
        'Site', 'Address', 'Borough', 'Council', 'Singles', 'Doubles', 'Triples',
        'Flats', 'Houses', 'Total units', 'Elevators', 'Verification status', 'Last updated',
    ];

    /** Columns that are summed into the company-total row. */
    public const NUMERIC_COLUMNS = [
        'Singles', 'Doubles', 'Triples', 'WC SC units', 'Flats', 'Houses',
        'Total units', 'Elevators', 'Staircases', 'Accessible bedrooms',
    ];

    /**
     * @param  Collection<int, Property>  $properties
     * @return array<int, array<string, mixed>>
     */
    public function rows(Collection $properties): array
    {
        return $properties->map(function (Property $property) {
            $accommodation = $property->accommodation;

            return [
                'Site' => $property->site_name ?? '',
                'Address' => $property->fullAddress(),
                'Borough' => $property->borough ?? '',
                'Council' => $property->council ?? '',
                'Region' => $property->region ?? '',
                'Property type' => $property->property_type ?? '',
                'Singles' => $accommodation?->count('singles') ?? 0,
                'Doubles' => $accommodation?->count('doubles') ?? 0,
                'Triples' => $accommodation?->count('triples') ?? 0,
                'WC SC units' => $accommodation?->count('wcSc') ?? 0,
                'Flats' => $property->flatsTotal(),
                'Houses' => $property->housesTotal(),
                'Total units' => $property->totalUnits(),
                'Elevators' => $property->elevators->count(),
                'Staircases' => $property->staircases->count(),
                'Accessible bedrooms' => (int) ($property->accessible_bedroom_count ?? 0),
                'Step-free entrance' => $property->step_free ?? '',
                'Manager' => $property->manager_name ?? '',
                'Verification status' => $property->verification_status,
                'Completeness %' => $property->completeness(),
                'Last updated' => $property->changeLogs->first()?->created_at?->format('Y-m-d H:i') ?? '—',
            ];
        })->all();
    }

    /**
     * Narrow rows to the requested columns, preserving the caller's order.
     *
     * @param  array<int, array<string, mixed>>  $rows
     * @param  array<int, string>  $columns
     * @return array<int, array<string, mixed>>
     */
    public function project(array $rows, array $columns): array
    {
        $columns = array_values(array_intersect($columns, self::ALL_COLUMNS));

        if ($columns === []) {
            $columns = self::DEFAULT_COLUMNS;
        }

        return array_map(
            fn (array $row) => array_reduce(
                $columns,
                function (array $carry, string $column) use ($row) {
                    $carry[$column] = $row[$column] ?? '';

                    return $carry;
                },
                [],
            ),
            $rows,
        );
    }

    /**
     * The yellow company-total row from the original report table.
     *
     * @param  array<int, array<string, mixed>>  $rows
     * @return array<string, mixed>
     */
    public function totalsRow(array $rows, array $columns): array
    {
        $totals = [];

        foreach ($columns as $column) {
            if ($column === 'Site') {
                $totals[$column] = 'Company total';

                continue;
            }

            $totals[$column] = in_array($column, self::NUMERIC_COLUMNS, true)
                ? array_sum(array_map(fn ($row) => (int) ($row[$column] ?? 0), $rows))
                : '';
        }

        return $totals;
    }

    /**
     * Portfolio-wide figures for the dashboard. Always computed over the
     * filtered set, so every number on screen reflects the current selection.
     *
     * @param  Collection<int, Property>  $properties
     */
    public function aggregate(Collection $properties): array
    {
        $totals = [
            'properties' => $properties->count(),
            'units' => 0, 'singles' => 0, 'doubles' => 0, 'triples' => 0,
            'wcSc' => 0, 'flats' => 0, 'houses' => 0, 'lifts' => 0,
            'staircases' => 0, 'accessibleRooms' => 0, 'verified' => 0, 'awaiting' => 0,
        ];

        $byBorough = [];
        $byStatus = [];
        $completenessSum = 0;

        foreach ($properties as $property) {
            $accommodation = $property->accommodation;
            $units = $property->totalUnits();

            $totals['units'] += $units;
            $totals['singles'] += $accommodation?->count('singles') ?? 0;
            $totals['doubles'] += $accommodation?->count('doubles') ?? 0;
            $totals['triples'] += $accommodation?->count('triples') ?? 0;
            $totals['wcSc'] += $accommodation?->count('wcSc') ?? 0;
            $totals['flats'] += $property->flatsTotal();
            $totals['houses'] += $property->housesTotal();
            $totals['lifts'] += $property->elevators->count();
            $totals['staircases'] += $property->staircases->count();
            $totals['accessibleRooms'] += (int) ($property->accessible_bedroom_count ?? 0);

            if ($property->verification_status === Property::STATUS_VERIFIED) {
                $totals['verified']++;
            } else {
                $totals['awaiting']++;
            }

            $borough = $property->borough ?: 'Unassigned';
            $byBorough[$borough] = ($byBorough[$borough] ?? 0) + $units;

            $status = $property->verification_status;
            $byStatus[$status] = ($byStatus[$status] ?? 0) + 1;

            $completenessSum += $property->completeness();
        }

        $totals['avgComplete'] = $properties->count() > 0
            ? (int) round($completenessSum / $properties->count())
            : 0;

        arsort($byBorough);

        return [
            'totals' => $totals,
            'byBorough' => array_map(
                fn ($name, $units) => ['name' => $name, 'units' => $units],
                array_keys($byBorough),
                array_values($byBorough),
            ),
            'byStatus' => array_map(
                fn ($name, $value) => ['name' => $name, 'value' => $value],
                array_keys($byStatus),
                array_values($byStatus),
            ),
        ];
    }

    /**
     * Properties that need someone's attention: under 80% complete, or sitting
     * in a status that means work is outstanding.
     *
     * @param  Collection<int, Property>  $properties
     * @return Collection<int, Property>
     */
    public function needingAttention(Collection $properties): Collection
    {
        return $properties->filter(fn (Property $property) => $property->completeness() < 80
            || in_array($property->verification_status, [
                Property::STATUS_OVERDUE,
                Property::STATUS_CHANGES_REQUESTED,
                Property::STATUS_NOT_STARTED,
            ], true))->values();
    }
}
