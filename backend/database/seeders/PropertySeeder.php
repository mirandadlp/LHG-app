<?php

namespace Database\Seeders;

use App\Models\ChangeLog;
use App\Models\Property;
use App\Models\User;
use App\Support\AccommodationRegistry;
use App\Support\FieldRegistry;
use Illuminate\Database\Seeder;

/**
 * The seven properties the prototype shipped with, reproduced faithfully so the
 * app has a realistic portfolio to demo and test against.
 *
 * Values are written in the client-facing field-key shape and mapped onto real
 * columns through FieldRegistry, so this stays readable next to the original.
 */
class PropertySeeder extends Seeder
{
    public function run(): void
    {
        foreach ($this->portfolio() as $entry) {
            $this->createProperty($entry);
        }
    }

    private function createProperty(array $entry): void
    {
        $values = $entry['values'];
        $attributes = ['verification_status' => $entry['verification']];

        foreach ($values as $key => $value) {
            $field = FieldRegistry::field($key);

            if (! $field) {
                continue;
            }

            if ($field['type'] === 'measurement') {
                $attributes[$field['column'].'_value'] = $value['v'] ?? null;
                $attributes[$field['column'].'_unit'] = $value['u'] ?? 'm²';

                continue;
            }

            $attributes[$field['column']] = $value;
        }

        $manager = ! empty($values['managerEmail'])
            ? User::where('email', $values['managerEmail'])->first()
            : null;

        $attributes['manager_id'] = $manager?->id;

        if ($entry['verification'] === Property::STATUS_VERIFIED) {
            $attributes['verified_at'] = now()->subDays(20);
        }

        if ($entry['verification'] === Property::STATUS_SUBMITTED) {
            $attributes['submitted_at'] = now()->subDays(3);
        }

        $property = Property::updateOrCreate(
            ['site_name' => $values['siteName']],
            $attributes,
        );

        /* -------------------- Accommodation -------------------- */
        $accommodation = $property->accommodation()->firstOrCreate([]);

        foreach (AccommodationRegistry::columnMap() as $key => $column) {
            $accommodation->{$column} = $entry['accommodation'][$key] ?? null;
        }

        $accommodation->save();

        /* -------------------- Lifts and stairs -------------------- */
        $property->elevators()->delete();

        foreach ($entry['elevators'] ?? [] as $index => $lift) {
            $property->elevators()->create([...$this->liftDefaults(), ...$lift, 'position' => $index]);
        }

        $property->staircases()->delete();

        foreach ($entry['staircases'] ?? [] as $index => $stair) {
            $property->staircases()->create([...$this->stairDefaults(), ...$stair, 'position' => $index]);
        }

        /* -------------------- Audit history -------------------- */
        $property->changeLogs()->delete();

        foreach ($entry['history'] ?? [] as $row) {
            $author = User::where('name', $row['by'])->first();

            ChangeLog::create([
                'property_id' => $property->id,
                'field' => $row['field'],
                'previous_value' => $row['prev'],
                'new_value' => $row['next'],
                'changed_by' => $author?->id,
                'changed_by_name' => $row['by'],
                'reason' => $row['reason'],
                'approval_status' => $row['approval'],
                'approved_at' => $row['approval'] === ChangeLog::APPROVED ? now()->subDays(5) : null,
                'created_at' => $row['date'],
                'updated_at' => $row['date'],
            ]);
        }

        /* -------------------- Documents -------------------- */
        $property->documents()->delete();

        foreach ($entry['documents'] ?? [] as $document) {
            $uploader = User::where('name', $document['by'])->first();

            $property->documents()->create([
                'name' => $document['name'],
                'type' => $document['type'],
                'disk' => 'local',
                // Seeded records describe documents that were migrated from the
                // legacy system; the binaries are attached on first real upload.
                'path' => 'seed-placeholder/'.$document['name'],
                'mime_type' => 'application/pdf',
                'size_bytes' => null,
                'notes' => $document['notes'] ?? null,
                'uploaded_by' => $uploader?->id,
                'uploaded_by_name' => $document['by'],
                'created_at' => $document['date'],
                'updated_at' => $document['date'],
            ]);
        }
    }

    private function liftDefaults(): array
    {
        return [
            'name' => '', 'type' => 'Passenger', 'capacity' => null, 'max_occupancy' => null,
            'width' => null, 'depth' => null, 'height' => null, 'door_width' => null,
            'accessible' => 'Yes', 'service' => 'No', 'passenger' => 'Yes', 'notes' => '',
        ];
    }

    private function stairDefaults(): array
    {
        return [
            'name' => '', 'location' => '', 'floors_served' => null, 'width' => null,
            'classification' => 'Standard', 'emergency_exit' => 'No', 'notes' => '',
        ];
    }

    /** @return array<int, array<string, mixed>> */
    private function portfolio(): array
    {
        return [
            [
                'verification' => Property::STATUS_IN_PROGRESS,
                'values' => [
                    'siteName' => 'Croydon Housing', 'propertyName' => 'Croydon Housing',
                    'addressLine1' => '142 London Road', 'addressLine2' => 'Broad Green', 'city' => 'Croydon',
                    'postcode' => 'CR0 2TB', 'borough' => 'Croydon', 'council' => 'Croydon Council',
                    'region' => 'London South', 'propertyType' => 'Residential Housing',
                    'ownershipCompany' => 'London PropCo 3 Ltd', 'managementCompany' => 'London Operations Ltd',
                    'manager' => 'Jane Smith', 'managerEmail' => 'jane.smith@londonhotelgroup.co.uk',
                    'managerPhone' => '020 7946 0112', 'operationalStatus' => 'Open', 'openedDate' => '2016-04-11',
                    'generalNotes' => 'Legacy records held in three separate spreadsheets prior to migration.',
                    'singleSize' => ['v' => 9.2, 'u' => 'm²'], 'doubleSize' => ['v' => 13.4, 'u' => 'm²'],
                    'tripleSize' => ['v' => 17.1, 'u' => 'm²'], 'avgBedroom' => ['v' => 12.6, 'u' => 'm²'],
                    'minBedroom' => ['v' => 8.1, 'u' => 'm²'], 'maxBedroom' => ['v' => 22.4, 'u' => 'm²'],
                    'wheelchairEntrance' => 'Yes', 'stepFree' => 'Yes', 'accessibleBedrooms' => 'Yes',
                    'accessibleBedroomCount' => 14, 'accessibleBathrooms' => 'Yes', 'accessibleElevators' => 'Yes',
                    'accessibleParking' => 'Yes', 'rampAccess' => 'Yes', 'handrails' => 'Yes',
                    'hearingAssistance' => 'No', 'visualAssistance' => 'No',
                    'floors' => 7, 'buildingArea' => ['v' => 8420, 'u' => 'm²'], 'buildingCount' => 2,
                    'entrances' => 3, 'emergencyExits' => 6, 'parkingSpaces' => 42, 'accessibleParkingSpaces' => 4,
                    'buildingType' => 'Converted Office', 'constructionYear' => 1974, 'renovationYear' => 2019,
                    'fireSafety' => 'L1 addressable alarm system. Sprinklers on floors 1–7. FRA completed March 2026.',
                ],
                'accommodation' => [
                    'singles' => 105, 'doubles' => 72, 'triples' => 38, 'wcSc' => 47,
                    'flat1' => 33, 'flat2' => 24, 'flat3' => 12, 'wcFlats' => 4, 'wcHouses' => 4,
                ],
                'elevators' => [
                    ['name' => 'Lift A — Main Core', 'type' => 'Passenger', 'capacity' => 8, 'max_occupancy' => 8,
                        'width' => 1.1, 'depth' => 1.4, 'height' => 2.2, 'door_width' => 0.9,
                        'accessible' => 'Yes', 'passenger' => 'Yes', 'service' => 'No', 'notes' => 'Serves floors G–7.'],
                    ['name' => 'Lift B — Goods', 'type' => 'Service', 'capacity' => 12, 'max_occupancy' => 12,
                        'width' => 1.4, 'depth' => 2.1, 'height' => 2.3, 'door_width' => 1.1,
                        'accessible' => 'No', 'passenger' => 'No', 'service' => 'Yes', 'notes' => 'Housekeeping and deliveries only.'],
                ],
                'staircases' => [
                    ['name' => 'Stair 1', 'location' => 'North core', 'floors_served' => 8, 'width' => 1.2,
                        'classification' => 'Emergency', 'emergency_exit' => 'Yes'],
                    ['name' => 'Stair 2', 'location' => 'South core', 'floors_served' => 8, 'width' => 1.1,
                        'classification' => 'Standard', 'emergency_exit' => 'No'],
                ],
                'documents' => [
                    ['name' => 'Croydon-Housing-Floorplans-2019.pdf', 'type' => 'Floor Plan',
                        'date' => '2026-06-02', 'by' => 'Jane Smith', 'notes' => 'Post-refurbishment set.'],
                    ['name' => 'Croydon-Accessibility-Audit.pdf', 'type' => 'Accessibility Report',
                        'date' => '2026-05-14', 'by' => 'Priya Raman', 'notes' => ''],
                ],
                'history' => [
                    ['field' => 'Singles', 'prev' => '98', 'next' => '105', 'by' => 'Jane Smith',
                        'date' => '2026-08-12 09:41:00', 'reason' => 'Property manager verification', 'approval' => 'Pending'],
                    ['field' => 'Number of accessible bedrooms', 'prev' => '12', 'next' => '14', 'by' => 'Jane Smith',
                        'date' => '2026-08-12 09:38:00', 'reason' => 'Two rooms converted in 2025', 'approval' => 'Pending'],
                    ['field' => 'Most recent renovation year', 'prev' => '—', 'next' => '2019', 'by' => 'Priya Raman',
                        'date' => '2026-07-30 15:02:00', 'reason' => 'Migrated from legacy spreadsheet', 'approval' => 'Approved'],
                ],
            ],
            [
                'verification' => Property::STATUS_VERIFIED,
                'values' => [
                    'siteName' => 'Lewisham Lodge Hotel', 'propertyName' => 'Lewisham Lodge',
                    'addressLine1' => '8 Rennell Street', 'city' => 'London', 'postcode' => 'SE13 7HD',
                    'borough' => 'Lewisham', 'council' => 'Lewisham Council', 'region' => 'London South',
                    'propertyType' => 'Hotel', 'ownershipCompany' => 'London PropCo 1 Ltd',
                    'managementCompany' => 'London Operations Ltd', 'manager' => 'David Okafor',
                    'managerEmail' => 'david.okafor@londonhotelgroup.co.uk', 'managerPhone' => '020 7946 0187',
                    'operationalStatus' => 'Open', 'openedDate' => '2012-09-01',
                    'singleSize' => ['v' => 11, 'u' => 'm²'], 'doubleSize' => ['v' => 15.5, 'u' => 'm²'],
                    'avgBedroom' => ['v' => 14, 'u' => 'm²'], 'minBedroom' => ['v' => 10.2, 'u' => 'm²'],
                    'maxBedroom' => ['v' => 26, 'u' => 'm²'],
                    'wheelchairEntrance' => 'Yes', 'stepFree' => 'Yes', 'accessibleBedrooms' => 'Yes',
                    'accessibleBedroomCount' => 9, 'accessibleBathrooms' => 'Yes', 'accessibleElevators' => 'Yes',
                    'accessibleParking' => 'No', 'rampAccess' => 'Yes', 'handrails' => 'Yes',
                    'hearingAssistance' => 'Yes', 'visualAssistance' => 'Yes',
                    'floors' => 5, 'buildingArea' => ['v' => 5100, 'u' => 'm²'], 'buildingCount' => 1,
                    'entrances' => 2, 'emergencyExits' => 4, 'parkingSpaces' => 18, 'accessibleParkingSpaces' => 2,
                    'buildingType' => 'Purpose-built', 'constructionYear' => 2005, 'renovationYear' => 2022,
                    'fireSafety' => 'L2 system, annual certification current.',
                ],
                'accommodation' => [
                    'singles' => 64, 'doubles' => 88, 'triples' => 21, 'wcSc' => 12, 'flat1' => 6, 'flat2' => 2,
                ],
                'elevators' => [
                    ['name' => 'Guest Lift 1', 'capacity' => 10, 'max_occupancy' => 10, 'width' => 1.2, 'depth' => 1.5, 'door_width' => 0.9],
                    ['name' => 'Guest Lift 2', 'capacity' => 10, 'max_occupancy' => 10, 'width' => 1.2, 'depth' => 1.5, 'door_width' => 0.9],
                    ['name' => 'Service Lift', 'type' => 'Service', 'capacity' => 14, 'accessible' => 'No', 'passenger' => 'No', 'service' => 'Yes'],
                ],
                'staircases' => [
                    ['name' => 'Main Stair', 'location' => 'Lobby', 'floors_served' => 6, 'width' => 1.4,
                        'classification' => 'Emergency', 'emergency_exit' => 'Yes'],
                ],
                'documents' => [
                    ['name' => 'Lewisham-Fire-Cert-2026.pdf', 'type' => 'Certificate',
                        'date' => '2026-03-11', 'by' => 'David Okafor', 'notes' => ''],
                ],
                'history' => [
                    ['field' => 'Verification', 'prev' => 'Submitted', 'next' => 'Verified', 'by' => 'Priya Raman',
                        'date' => '2026-07-22 11:15:00', 'reason' => 'Approved after review', 'approval' => 'Approved'],
                ],
            ],
            [
                'verification' => Property::STATUS_SUBMITTED,
                'values' => [
                    'siteName' => 'Newham Riverside House', 'propertyName' => 'Riverside House',
                    'addressLine1' => '24 Cundy Road', 'city' => 'London', 'postcode' => 'E16 3DJ',
                    'borough' => 'Newham', 'council' => 'Newham Council', 'region' => 'London East',
                    'propertyType' => 'Temporary Accommodation', 'ownershipCompany' => 'London PropCo 2 Ltd',
                    'managementCompany' => 'London Operations Ltd', 'manager' => 'Aisha Khan',
                    'managerEmail' => 'aisha.khan@londonhotelgroup.co.uk', 'managerPhone' => '020 7946 0233',
                    'operationalStatus' => 'Open', 'openedDate' => '2018-02-19',
                    'singleSize' => ['v' => 8.6, 'u' => 'm²'], 'doubleSize' => ['v' => 12.9, 'u' => 'm²'],
                    'avgBedroom' => ['v' => 11.4, 'u' => 'm²'],
                    'wheelchairEntrance' => 'Yes', 'stepFree' => 'No', 'accessibleBedrooms' => 'Yes',
                    'accessibleBedroomCount' => 6, 'accessibleBathrooms' => 'Yes', 'accessibleElevators' => 'Yes',
                    'accessibleParking' => 'No', 'rampAccess' => 'Yes', 'handrails' => 'Yes', 'hearingAssistance' => 'No',
                    'floors' => 6, 'buildingCount' => 1, 'entrances' => 2, 'emergencyExits' => 4,
                    'parkingSpaces' => 12, 'accessibleParkingSpaces' => 1,
                    'buildingType' => 'Converted Office', 'constructionYear' => 1988,
                ],
                'accommodation' => [
                    'singles' => 78, 'doubles' => 54, 'triples' => 44, 'wcSc' => 30,
                    'flat1' => 18, 'flat2' => 22, 'flat3' => 9, 'house3' => 3,
                ],
                'elevators' => [
                    ['name' => 'Lift 1', 'capacity' => 8],
                    ['name' => 'Lift 2', 'type' => 'Service', 'capacity' => 10, 'accessible' => 'No', 'passenger' => 'No', 'service' => 'Yes'],
                ],
                'staircases' => [
                    ['name' => 'East Stair', 'location' => 'East wing', 'floors_served' => 7, 'width' => 1.1,
                        'classification' => 'Emergency', 'emergency_exit' => 'Yes'],
                ],
                'documents' => [],
                'history' => [
                    ['field' => 'Triples', 'prev' => '28', 'next' => '44', 'by' => 'Aisha Khan',
                        'date' => '2026-08-10 16:20:00', 'reason' => 'Reconfiguration completed July 2026', 'approval' => 'Pending'],
                ],
            ],
            [
                'verification' => Property::STATUS_VERIFIED,
                'values' => [
                    'siteName' => 'Greenwich Court Apartments', 'propertyName' => 'Greenwich Court',
                    'addressLine1' => '3 Norman Road', 'city' => 'London', 'postcode' => 'SE10 9QX',
                    'borough' => 'Greenwich', 'council' => 'Royal Borough of Greenwich', 'region' => 'London South',
                    'propertyType' => 'Serviced Apartments', 'ownershipCompany' => 'London PropCo 1 Ltd',
                    'managementCompany' => 'London Operations Ltd', 'manager' => 'Tom Reilly',
                    'managerEmail' => 'tom.reilly@londonhotelgroup.co.uk', 'managerPhone' => '020 7946 0301',
                    'operationalStatus' => 'Open', 'openedDate' => '2021-06-30',
                    'singleSize' => ['v' => 12, 'u' => 'm²'], 'doubleSize' => ['v' => 16.8, 'u' => 'm²'],
                    'avgBedroom' => ['v' => 15.2, 'u' => 'm²'], 'minBedroom' => ['v' => 11, 'u' => 'm²'],
                    'maxBedroom' => ['v' => 24, 'u' => 'm²'],
                    'wheelchairEntrance' => 'Yes', 'stepFree' => 'Yes', 'accessibleBedrooms' => 'Yes',
                    'accessibleBedroomCount' => 11, 'accessibleBathrooms' => 'Yes', 'accessibleElevators' => 'Yes',
                    'accessibleParking' => 'Yes', 'rampAccess' => 'Yes', 'handrails' => 'Yes',
                    'hearingAssistance' => 'Yes', 'visualAssistance' => 'Yes',
                    'floors' => 9, 'buildingArea' => ['v' => 11200, 'u' => 'm²'], 'buildingCount' => 1,
                    'entrances' => 2, 'emergencyExits' => 5, 'parkingSpaces' => 60, 'accessibleParkingSpaces' => 6,
                    'buildingType' => 'New Build', 'constructionYear' => 2020, 'renovationYear' => 2020,
                    'fireSafety' => 'Sprinklered throughout. L1 system.',
                ],
                'accommodation' => [
                    'flat1' => 64, 'flat2' => 48, 'flat3' => 18, 'wcFlats' => 6, 'doubles' => 12,
                ],
                'elevators' => [
                    ['name' => 'Core A Lift 1', 'capacity' => 13],
                    ['name' => 'Core A Lift 2', 'capacity' => 13],
                    ['name' => 'Core B Lift', 'capacity' => 8],
                    ['name' => 'Service Lift', 'type' => 'Service', 'capacity' => 16, 'accessible' => 'No', 'passenger' => 'No', 'service' => 'Yes'],
                ],
                'staircases' => [
                    ['name' => 'Core A Stair', 'location' => 'Core A', 'floors_served' => 10, 'width' => 1.3,
                        'classification' => 'Emergency', 'emergency_exit' => 'Yes'],
                    ['name' => 'Core B Stair', 'location' => 'Core B', 'floors_served' => 10, 'width' => 1.3,
                        'classification' => 'Emergency', 'emergency_exit' => 'Yes'],
                ],
                'documents' => [
                    ['name' => 'Greenwich-Survey-2021.pdf', 'type' => 'Property Survey',
                        'date' => '2026-01-09', 'by' => 'Tom Reilly', 'notes' => ''],
                ],
                'history' => [],
            ],
            [
                'verification' => Property::STATUS_CHANGES_REQUESTED,
                'values' => [
                    'siteName' => 'Ealing Park Hostel', 'propertyName' => 'Ealing Park',
                    'addressLine1' => '77 Uxbridge Road', 'city' => 'London', 'postcode' => 'W5 5SL',
                    'borough' => 'Ealing', 'council' => 'Ealing Council', 'region' => 'London West',
                    'propertyType' => 'Hostel', 'ownershipCompany' => 'London PropCo 3 Ltd',
                    'managementCompany' => 'London Operations Ltd', 'manager' => 'Marta Nowak',
                    'managerEmail' => 'marta.nowak@londonhotelgroup.co.uk',
                    'operationalStatus' => 'Open', 'openedDate' => '2019-11-05',
                    'avgBedroom' => ['v' => 10.1, 'u' => 'm²'],
                    'wheelchairEntrance' => 'No', 'stepFree' => 'No', 'accessibleBedrooms' => 'No',
                    'accessibleBedroomCount' => 0, 'accessibleBathrooms' => 'No', 'accessibleElevators' => 'N/A',
                    'rampAccess' => 'No', 'handrails' => 'Yes',
                    'floors' => 4, 'buildingCount' => 1, 'entrances' => 1, 'emergencyExits' => 2,
                    'buildingType' => 'Victorian Terrace', 'constructionYear' => 1901,
                ],
                'accommodation' => ['singles' => 40, 'doubles' => 36, 'triples' => 26, 'wcSc' => 8],
                'elevators' => [],
                'staircases' => [
                    ['name' => 'Main Stair', 'location' => 'Central', 'floors_served' => 5, 'width' => 0.9,
                        'classification' => 'Emergency', 'emergency_exit' => 'Yes'],
                ],
                'documents' => [],
                'history' => [
                    ['field' => 'Verification', 'prev' => 'Submitted', 'next' => 'Changes Requested', 'by' => 'Priya Raman',
                        'date' => '2026-08-05 10:02:00', 'reason' => 'Room dimensions and fire safety information missing',
                        'approval' => 'Approved'],
                ],
            ],
            [
                'verification' => Property::STATUS_NOT_STARTED,
                'values' => [
                    'siteName' => 'Camden Row Residences', 'propertyName' => 'Camden Row',
                    'addressLine1' => '12 Bayham Street', 'city' => 'London', 'postcode' => 'NW1 0EY',
                    'borough' => 'Camden', 'council' => 'Camden Council', 'region' => 'London North',
                    'propertyType' => 'Mixed Use', 'manager' => 'Unassigned', 'operationalStatus' => 'Open',
                ],
                'accommodation' => ['singles' => 22, 'doubles' => 18, 'flat1' => 9, 'flat2' => 6],
                'elevators' => [],
                'staircases' => [],
                'documents' => [],
                'history' => [],
            ],
            [
                'verification' => Property::STATUS_OVERDUE,
                'values' => [
                    'siteName' => 'Barking Gateway House', 'propertyName' => 'Gateway House',
                    'addressLine1' => '5 Abbey Road', 'city' => 'Barking', 'postcode' => 'IG11 7BT',
                    'borough' => 'Barking & Dagenham', 'council' => 'Barking & Dagenham Council',
                    'region' => 'London East', 'propertyType' => 'Temporary Accommodation',
                    'ownershipCompany' => 'London PropCo 2 Ltd', 'manager' => 'Sam Whitfield',
                    'managerEmail' => 'sam.whitfield@londonhotelgroup.co.uk',
                    'operationalStatus' => 'Partially Open', 'floors' => 5, 'emergencyExits' => 3,
                    'buildingCount' => 1, 'wheelchairEntrance' => 'Yes', 'stepFree' => 'Yes',
                    'accessibleBedroomCount' => 4, 'accessibleBedrooms' => 'Yes',
                ],
                'accommodation' => [
                    'singles' => 55, 'doubles' => 31, 'triples' => 12, 'wcSc' => 20,
                    'flat2' => 14, 'house3' => 6, 'house4' => 2,
                ],
                'elevators' => [['name' => 'Lift 1', 'capacity' => 8]],
                'staircases' => [
                    ['name' => 'Stair A', 'location' => 'North', 'floors_served' => 6, 'width' => 1.1,
                        'emergency_exit' => 'Yes', 'classification' => 'Emergency'],
                ],
                'documents' => [],
                'history' => [],
            ],
        ];
    }
}
