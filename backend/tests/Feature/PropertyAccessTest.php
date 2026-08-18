<?php

namespace Tests\Feature;

use App\Models\Property;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Role boundaries. These are the rules that stop a property manager editing
 * someone else's building and stop leadership editing anything at all.
 */
class PropertyAccessTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    protected $seeder = DatabaseSeeder::class;

    public function test_an_administrator_sees_the_whole_portfolio(): void
    {
        $this->actingAsUser($this->admin());

        $this->getJson('/api/properties')
            ->assertOk()
            ->assertJsonCount(7);
    }

    public function test_leadership_sees_the_whole_portfolio(): void
    {
        $this->actingAsUser($this->leadership());

        $this->getJson('/api/properties')
            ->assertOk()
            ->assertJsonCount(7);
    }

    public function test_a_property_manager_sees_only_their_own_properties(): void
    {
        $this->actingAsUser($this->manager());

        $response = $this->getJson('/api/properties')->assertOk();

        $this->assertCount(1, $response->json());
        $this->assertSame('Croydon Housing', $response->json('0.siteName'));
    }

    public function test_a_property_manager_cannot_open_another_managers_property(): void
    {
        $lewisham = Property::where('site_name', 'Lewisham Lodge Hotel')->firstOrFail();

        $this->actingAsUser($this->manager());

        $this->getJson("/api/properties/{$lewisham->id}")->assertForbidden();
    }

    public function test_a_property_manager_can_edit_their_own_property(): void
    {
        $this->actingAsUser($this->manager());

        $this->patchJson("/api/properties/{$this->croydon()->id}", [
            'values' => ['managerPhone' => '020 7946 9999'],
        ])->assertOk()->assertJsonPath('values.managerPhone', '020 7946 9999');
    }

    public function test_a_property_manager_cannot_edit_another_managers_property(): void
    {
        $lewisham = Property::where('site_name', 'Lewisham Lodge Hotel')->firstOrFail();

        $this->actingAsUser($this->manager());

        $this->patchJson("/api/properties/{$lewisham->id}", [
            'values' => ['managerPhone' => '000'],
        ])->assertForbidden();

        $this->assertSame('020 7946 0187', $lewisham->fresh()->manager_phone);
    }

    public function test_leadership_is_read_only(): void
    {
        $this->actingAsUser($this->leadership());

        $croydon = $this->croydon();

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['managerPhone' => '000'],
        ])->assertForbidden();

        $this->postJson('/api/properties', [
            'values' => ['siteName' => 'Should Not Exist'],
        ])->assertForbidden();

        $this->postJson("/api/properties/{$croydon->id}/approve")->assertForbidden();

        $this->assertDatabaseMissing('properties', ['site_name' => 'Should Not Exist']);
    }

    public function test_only_administrators_reach_the_admin_endpoints(): void
    {
        foreach ([$this->manager(), $this->leadership()] as $user) {
            $this->actingAsUser($user);

            $this->getJson('/api/field-definitions')->assertForbidden();
            $this->getJson('/api/import/sample')->assertForbidden();
            $this->postJson('/api/option-lists/boroughs', ['value' => 'Hackney'])->assertForbidden();
        }

        $this->actingAsUser($this->admin());
        $this->getJson('/api/field-definitions')->assertOk();
    }

    public function test_a_submitted_record_is_locked_to_its_manager(): void
    {
        $croydon = $this->croydon();
        $croydon->update(['verification_status' => Property::STATUS_SUBMITTED]);

        $this->actingAsUser($this->manager());

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['managerPhone' => '020 0000 0000'],
        ])->assertForbidden();

        // Corporate can still correct it while reviewing.
        $this->actingAsUser($this->admin());

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['managerPhone' => '020 0000 0000'],
        ])->assertOk();
    }
}
