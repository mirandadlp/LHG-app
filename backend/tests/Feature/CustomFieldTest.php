<?php

namespace Tests\Feature;

use App\Models\FieldDefinition;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The promise of the admin screen: a field added this morning is collected,
 * validated, stored and reported on this afternoon, with no release.
 */
class CustomFieldTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    protected $seeder = DatabaseSeeder::class;

    public function test_the_registry_lists_base_and_custom_fields(): void
    {
        $this->actingAsUser($this->admin());

        $fields = $this->getJson('/api/bootstrap')->assertOk()->json('fields');

        $keys = array_column($fields, 'key');

        $this->assertContains('siteName', $keys);
        $this->assertContains('cf_boilers', $keys); // The seeded custom field.

        $custom = collect($fields)->firstWhere('key', 'cf_boilers');

        $this->assertTrue($custom['custom']);
        $this->assertSame('building', $custom['section']);
    }

    public function test_a_new_field_appears_on_every_property_immediately(): void
    {
        $this->actingAsUser($this->admin());

        $this->postJson('/api/field-definitions', [
            'label' => 'Number of fire doors',
            'section' => 'building',
            'type' => 'number',
            'required' => false,
            'help' => 'Counted during the 2026 survey.',
        ])->assertCreated();

        $definition = FieldDefinition::where('label', 'Number of fire doors')->firstOrFail();

        $this->assertTrue($definition->is_custom);
        $this->assertSame('cf_number_of_fire_doors', $definition->key);

        // It is now part of the record for a property nobody has touched.
        $values = $this->getJson("/api/properties/{$this->croydon()->id}")->assertOk()->json('values');

        $this->assertArrayHasKey('cf_number_of_fire_doors', $values);
        $this->assertNull($values['cf_number_of_fire_doors']);
    }

    public function test_a_custom_field_stores_validates_and_audits_like_any_other(): void
    {
        $this->actingAsUser($this->admin());

        $this->postJson('/api/field-definitions', [
            'label' => 'Number of fire doors',
            'section' => 'building',
            'type' => 'number',
        ])->assertCreated();

        $croydon = $this->croydon();

        // Rejected the same way a base numeric field would be.
        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['cf_number_of_fire_doors' => -5],
        ])->assertStatus(422)->assertJsonValidationErrors('values.cf_number_of_fire_doors');

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['cf_number_of_fire_doors' => 42],
        ])->assertOk()->assertJsonPath('values.cf_number_of_fire_doors', 42);

        $this->assertDatabaseHas('change_logs', [
            'property_id' => $croydon->id,
            'field' => 'Number of fire doors',
            'new_value' => '42',
        ]);
    }

    public function test_a_dropdown_field_only_accepts_its_own_options(): void
    {
        $this->actingAsUser($this->admin());

        $this->postJson('/api/field-definitions', [
            'label' => 'Heating type',
            'section' => 'building',
            'type' => 'dropdown',
            'optionList' => ['Gas', 'Electric', 'District'],
        ])->assertCreated();

        $croydon = $this->croydon();

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['cf_heating_type' => 'Coal'],
        ])->assertStatus(422);

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['cf_heating_type' => 'District'],
        ])->assertOk()->assertJsonPath('values.cf_heating_type', 'District');
    }

    public function test_removing_a_custom_field_removes_its_stored_values(): void
    {
        $this->actingAsUser($this->admin());

        $croydon = $this->croydon();

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['cf_boilers' => 3],
        ])->assertOk();

        $this->assertDatabaseCount('property_field_values', 1);

        $definition = FieldDefinition::where('key', 'cf_boilers')->firstOrFail();

        $this->deleteJson("/api/field-definitions/{$definition->id}")->assertOk();

        $this->assertDatabaseCount('property_field_values', 0);
        $this->assertArrayNotHasKey(
            'cf_boilers',
            $this->getJson("/api/properties/{$croydon->id}")->json('values'),
        );
    }

    public function test_base_fields_cannot_be_deleted(): void
    {
        $this->actingAsUser($this->admin());

        $siteName = FieldDefinition::where('key', 'siteName')->firstOrFail();

        $this->deleteJson("/api/field-definitions/{$siteName->id}")->assertStatus(422);

        $this->assertDatabaseHas('field_definitions', ['key' => 'siteName']);
    }

    public function test_dropdown_lists_can_be_extended_and_trimmed(): void
    {
        $this->actingAsUser($this->admin());

        $this->postJson('/api/option-lists/boroughs', ['value' => 'Hackney'])
            ->assertCreated()
            ->assertJsonFragment(['Hackney']);

        // The new borough is now a valid value on a property.
        $this->patchJson("/api/properties/{$this->croydon()->id}", [
            'values' => ['borough' => 'Hackney'],
        ])->assertOk();

        $this->deleteJson('/api/option-lists/boroughs/Hackney')->assertOk();

        $this->assertDatabaseMissing('option_list_items', [
            'list_key' => 'boroughs',
            'value' => 'Hackney',
        ]);
    }

    public function test_completeness_accounts_for_newly_added_fields(): void
    {
        $this->actingAsUser($this->admin());

        $croydon = $this->croydon();
        $before = $this->getJson("/api/properties/{$croydon->id}")->json('completeness');

        // Adding fields nobody has filled in must lower the score, not flatter it.
        foreach (range(1, 5) as $index) {
            $this->postJson('/api/field-definitions', [
                'label' => "Survey metric {$index}",
                'section' => 'building',
                'type' => 'number',
            ])->assertCreated();
        }

        $after = $this->getJson("/api/properties/{$croydon->id}")->json('completeness');

        $this->assertLessThan($before, $after);
    }
}
