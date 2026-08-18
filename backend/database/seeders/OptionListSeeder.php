<?php

namespace Database\Seeders;

use App\Models\OptionListItem;
use Illuminate\Database\Seeder;

class OptionListSeeder extends Seeder
{
    /** The controlled lists exactly as the original app shipped them. */
    public const LISTS = [
        'boroughs' => [
            'Croydon', 'Lewisham', 'Newham', 'Greenwich',
            'Ealing', 'Camden', 'Barking & Dagenham',
        ],
        'councils' => [
            'Croydon Council', 'Lewisham Council', 'Newham Council',
            'Royal Borough of Greenwich', 'Ealing Council', 'Camden Council',
            'Barking & Dagenham Council',
        ],
        'regions' => [
            'London South', 'London East', 'London North', 'London West',
        ],
        'propertyTypes' => [
            'Hotel', 'Hostel', 'Temporary Accommodation',
            'Serviced Apartments', 'Residential Housing', 'Mixed Use',
        ],
        'operationalStatuses' => [
            'Open', 'Partially Open', 'Closed for Refurbishment', 'Pre-Opening',
        ],
        'buildingTypes' => [
            'Purpose-built', 'Converted Office', 'Converted Residential',
            'Victorian Terrace', 'New Build',
        ],
        'elevatorTypes' => [
            'Passenger', 'Service', 'Goods', 'Platform Lift',
        ],
        'documentTypes' => [
            'Floor Plan', 'Property Survey', 'Building Specification',
            'Accessibility Report', 'Safety Documentation', 'Legacy Spreadsheet',
            'Photograph', 'Certificate',
        ],
    ];

    public function run(): void
    {
        foreach (self::LISTS as $listKey => $values) {
            foreach ($values as $index => $value) {
                OptionListItem::updateOrCreate(
                    ['list_key' => $listKey, 'value' => $value],
                    ['sort_order' => $index],
                );
            }
        }
    }
}
