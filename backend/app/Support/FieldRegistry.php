<?php

namespace App\Support;

/**
 * The single source of truth for the base field registry.
 *
 * The iOS client, the seeder, the spreadsheet importer and the report exporter
 * all read from here, so a field is described in exactly one place. Each entry
 * maps the client-facing key (camelCase, matching the original web app) to the
 * `properties` column that stores it.
 *
 * Measurement fields map to a pair of columns: `<column>_value` and `<column>_unit`.
 */
final class FieldRegistry
{
    public const SECTIONS = [
        ['id' => 'general', 'label' => 'General information'],
        ['id' => 'dimensions', 'label' => 'Room dimensions'],
        ['id' => 'accessibility', 'label' => 'Accessibility'],
        ['id' => 'building', 'label' => 'Building'],
    ];

    /**
     * @return array<int, array<string, mixed>>
     */
    public static function baseFields(): array
    {
        return [
            /* ---------------- General information ---------------- */
            self::f('siteName', 'general', 'Site name', 'text', 'site_name', required: true, help: 'The name used on internal reporting.'),
            self::f('propertyName', 'general', 'Property name', 'text', 'property_name', required: true),
            self::f('addressLine1', 'general', 'Address line 1', 'text', 'address_line1', required: true),
            self::f('addressLine2', 'general', 'Address line 2', 'text', 'address_line2'),
            self::f('city', 'general', 'City / town', 'text', 'city', required: true),
            self::f('postcode', 'general', 'Postal code', 'postcode', 'postcode', required: true, help: 'UK format, e.g. CR0 2RF.'),
            self::f('borough', 'general', 'Borough', 'select', 'borough', required: true, optionListKey: 'boroughs'),
            self::f('council', 'general', 'Council', 'select', 'council', required: true, optionListKey: 'councils'),
            self::f('region', 'general', 'Region', 'select', 'region', required: true, optionListKey: 'regions'),
            self::f('propertyType', 'general', 'Property type', 'select', 'property_type', required: true, optionListKey: 'propertyTypes'),
            self::f('ownershipCompany', 'general', 'Ownership company', 'text', 'ownership_company'),
            self::f('managementCompany', 'general', 'Management company', 'text', 'management_company'),
            self::f('manager', 'general', 'General manager / property manager', 'text', 'manager_name', required: true),
            self::f('managerEmail', 'general', 'Property manager email', 'email', 'manager_email', required: true),
            self::f('managerPhone', 'general', 'Property manager phone', 'text', 'manager_phone'),
            self::f('operationalStatus', 'general', 'Operational status', 'select', 'operational_status', required: true, optionListKey: 'operationalStatuses'),
            self::f('openedDate', 'general', 'Date property opened', 'date', 'opened_date'),
            self::f('generalNotes', 'general', 'Notes', 'notes', 'general_notes'),

            /* ---------------- Room dimensions ---------------- */
            self::f('singleSize', 'dimensions', 'Standard single room size', 'measurement', 'single_size'),
            self::f('doubleSize', 'dimensions', 'Standard double room size', 'measurement', 'double_size'),
            self::f('tripleSize', 'dimensions', 'Standard triple room size', 'measurement', 'triple_size'),
            self::f('avgBedroom', 'dimensions', 'Average bedroom size', 'measurement', 'avg_bedroom'),
            self::f('minBedroom', 'dimensions', 'Minimum bedroom size', 'measurement', 'min_bedroom'),
            self::f('maxBedroom', 'dimensions', 'Maximum bedroom size', 'measurement', 'max_bedroom'),
            self::f('dimensionNotes', 'dimensions', 'Measurement notes', 'notes', 'dimension_notes', help: 'Note how rooms were measured, e.g. internal floor area excluding en-suite.'),

            /* ---------------- Accessibility ---------------- */
            self::f('wheelchairEntrance', 'accessibility', 'Wheelchair accessible entrance', 'yesno', 'wheelchair_entrance', required: true),
            self::f('stepFree', 'accessibility', 'Step-free entrance', 'yesno', 'step_free', required: true),
            self::f('accessibleBedrooms', 'accessibility', 'Accessible bedrooms', 'yesno', 'accessible_bedrooms'),
            self::f('accessibleBedroomCount', 'accessibility', 'Number of accessible bedrooms', 'number', 'accessible_bedroom_count'),
            self::f('accessibleBathrooms', 'accessibility', 'Accessible bathrooms', 'yesno', 'accessible_bathrooms'),
            self::f('accessibleElevators', 'accessibility', 'Accessible elevators', 'yesno', 'accessible_elevators'),
            self::f('accessibleParking', 'accessibility', 'Accessible parking', 'yesno', 'accessible_parking'),
            self::f('rampAccess', 'accessibility', 'Ramp access', 'yesno', 'ramp_access'),
            self::f('handrails', 'accessibility', 'Handrails', 'yesno', 'handrails'),
            self::f('hearingAssistance', 'accessibility', 'Hearing assistance', 'yesno', 'hearing_assistance'),
            self::f('visualAssistance', 'accessibility', 'Visual assistance features', 'yesno', 'visual_assistance'),
            self::f('otherAccessibility', 'accessibility', 'Other accessibility features', 'text', 'other_accessibility'),
            self::f('accessibilityNotes', 'accessibility', 'Accessibility notes', 'notes', 'accessibility_notes'),

            /* ---------------- Building ---------------- */
            self::f('floors', 'building', 'Number of floors', 'number', 'floors', required: true),
            self::f('buildingArea', 'building', 'Total building area', 'measurement', 'building_area'),
            self::f('buildingCount', 'building', 'Number of buildings on site', 'number', 'building_count'),
            self::f('entrances', 'building', 'Number of entrances', 'number', 'entrances'),
            self::f('emergencyExits', 'building', 'Number of emergency exits', 'number', 'emergency_exits', required: true),
            self::f('parkingSpaces', 'building', 'Number of parking spaces', 'number', 'parking_spaces'),
            self::f('accessibleParkingSpaces', 'building', 'Number of accessible parking spaces', 'number', 'accessible_parking_spaces'),
            self::f('fireSafety', 'building', 'Fire safety information', 'notes', 'fire_safety', help: 'Alarm system, sprinklers, last fire risk assessment date.'),
            self::f('buildingType', 'building', 'Building type', 'select', 'building_type', optionListKey: 'buildingTypes'),
            self::f('constructionYear', 'building', 'Construction year', 'number', 'construction_year'),
            self::f('renovationYear', 'building', 'Most recent renovation year', 'number', 'renovation_year'),
            self::f('buildingNotes', 'building', 'Notes', 'notes', 'building_notes'),
        ];
    }

    private static function f(
        string $key,
        string $section,
        string $label,
        string $type,
        string $column,
        bool $required = false,
        ?string $help = null,
        ?string $optionListKey = null,
    ): array {
        return compact('key', 'section', 'label', 'type', 'column', 'required', 'help', 'optionListKey');
    }

    /** @return array<string, array<string, mixed>> keyed by field key */
    public static function byKey(): array
    {
        static $cache = null;

        return $cache ??= array_column(self::baseFields(), null, 'key');
    }

    public static function field(string $key): ?array
    {
        return self::byKey()[$key] ?? null;
    }

    /** Field keys that must be filled before a property may be submitted. */
    public static function requiredKeys(): array
    {
        return array_keys(array_filter(self::byKey(), fn ($f) => $f['required']));
    }

    /** @return array<string, string> field key => properties column */
    public static function columnMap(): array
    {
        return array_map(fn ($f) => $f['column'], self::byKey());
    }

    public static function isMeasurement(string $key): bool
    {
        return (self::field($key)['type'] ?? null) === 'measurement';
    }
}
