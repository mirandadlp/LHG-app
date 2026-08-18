<?php

namespace Tests\Unit;

use App\Support\AccommodationRegistry;
use App\Support\FieldRegistry;
use PHPUnit\Framework\TestCase;

/** The two calculations everything else is built on. */
class CompletenessAndTotalsTest extends TestCase
{
    public function test_the_registry_matches_the_original_field_set(): void
    {
        $fields = FieldRegistry::baseFields();

        // 18 general + 7 dimensions + 13 accessibility + 12 building.
        $this->assertCount(50, $fields);
        $this->assertCount(14, AccommodationRegistry::TYPES);

        // Every field maps to a real column and a known section.
        foreach ($fields as $field) {
            $this->assertNotEmpty($field['column'], "{$field['key']} has no column");
            $this->assertContains($field['section'], ['general', 'dimensions', 'accessibility', 'building']);
        }

        // Keys are unique — a collision would silently overwrite a value.
        $keys = array_column($fields, 'key');
        $this->assertSame(count($keys), count(array_unique($keys)));
    }

    public function test_the_required_field_set_is_the_expected_one(): void
    {
        $this->assertEqualsCanonicalizing([
            'siteName', 'propertyName', 'addressLine1', 'city', 'postcode',
            'borough', 'council', 'region', 'propertyType', 'manager',
            'managerEmail', 'operationalStatus', 'wheelchairEntrance',
            'stepFree', 'floors', 'emergencyExits',
        ], FieldRegistry::requiredKeys());
    }

    /**
     * A change is large when it moves at least 10 units AND at least half the
     * previous value. Both conditions, never one.
     */
    public function test_large_change_detection_boundaries(): void
    {
        // Both conditions met.
        $this->assertTrue(AccommodationRegistry::isLargeChange(38, 4));   // -34, -89%
        $this->assertTrue(AccommodationRegistry::isLargeChange(20, 10));  // -10, -50%
        $this->assertTrue(AccommodationRegistry::isLargeChange(20, 40));  // +20, +100%

        // Big proportion, too few units.
        $this->assertFalse(AccommodationRegistry::isLargeChange(8, 0));   // -8, -100%
        $this->assertFalse(AccommodationRegistry::isLargeChange(4, 12));  // +8, +200%

        // Many units, too small a proportion.
        $this->assertFalse(AccommodationRegistry::isLargeChange(100, 88)); // -12, -12%

        // Exactly on both thresholds counts.
        $this->assertFalse(AccommodationRegistry::isLargeChange(20, 11));  // -9, under 10 units

        // Growth from nothing is data entry, not a suspicious correction.
        $this->assertFalse(AccommodationRegistry::isLargeChange(0, 500));

        // No movement at all.
        $this->assertFalse(AccommodationRegistry::isLargeChange(50, 50));
    }

    public function test_accommodation_groups_partition_every_type(): void
    {
        $grouped = [];

        foreach (AccommodationRegistry::keys() as $key) {
            $grouped[AccommodationRegistry::group($key)][] = $key;
        }

        $this->assertSame(
            count(AccommodationRegistry::TYPES),
            array_sum(array_map('count', $grouped)),
        );

        $this->assertSame(AccommodationRegistry::ROOM_KEYS, $grouped['Rooms']);
        $this->assertSame(AccommodationRegistry::FLAT_KEYS, $grouped['Flats']);
        $this->assertSame(AccommodationRegistry::HOUSE_KEYS, $grouped['Houses']);
    }
}
