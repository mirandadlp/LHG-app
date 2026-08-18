<?php

namespace Tests\Feature;

use App\Models\ChangeFlag;
use App\Models\ChangeLog;
use App\Models\Property;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Editing behaviour: the audit trail, measurement handling, large-change
 * detection and the sub-records (lifts, stairs).
 */
class PropertyEditingTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    protected $seeder = DatabaseSeeder::class;

    public function test_every_edit_writes_an_audit_row(): void
    {
        $croydon = $this->croydon();
        $before = $croydon->changeLogs()->count();

        $this->actingAsUser($this->manager());

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['floors' => 8],
        ])->assertOk();

        $this->assertSame($before + 1, $croydon->fresh()->changeLogs()->count());

        $this->assertDatabaseHas('change_logs', [
            'property_id' => $croydon->id,
            'field' => 'Number of floors',
            'previous_value' => '7',
            'new_value' => '8',
            'changed_by_name' => 'Jane Smith',
            'reason' => 'Property manager verification',
            'approval_status' => ChangeLog::PENDING,
        ]);
    }

    public function test_writing_the_same_value_records_nothing(): void
    {
        $croydon = $this->croydon();
        $before = $croydon->changeLogs()->count();

        $this->actingAsUser($this->manager());

        // 7 floors is already the stored value.
        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['floors' => 7],
        ])->assertOk();

        $this->assertSame($before, $croydon->fresh()->changeLogs()->count());
    }

    public function test_measurements_round_trip_with_their_unit(): void
    {
        $croydon = $this->croydon();

        $this->actingAsUser($this->manager());

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['avgBedroom' => ['v' => 13.75, 'u' => 'ft²']],
        ])->assertOk()
            ->assertJsonPath('values.avgBedroom.v', 13.75)
            ->assertJsonPath('values.avgBedroom.u', 'ft²');

        $fresh = $croydon->fresh();

        $this->assertSame(13.75, (float) $fresh->avg_bedroom_value);
        $this->assertSame('ft²', $fresh->avg_bedroom_unit);
    }

    public function test_an_invalid_value_is_rejected_before_it_is_stored(): void
    {
        $croydon = $this->croydon();

        $this->actingAsUser($this->manager());

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['managerEmail' => 'not-an-email'],
        ])->assertStatus(422)->assertJsonValidationErrors('values.managerEmail');

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['postcode' => 'NOPE'],
        ])->assertStatus(422)->assertJsonValidationErrors('values.postcode');

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['floors' => -3],
        ])->assertStatus(422)->assertJsonValidationErrors('values.floors');

        $this->patchJson("/api/properties/{$croydon->id}", [
            'values' => ['borough' => 'Atlantis'],
        ])->assertStatus(422)->assertJsonValidationErrors('values.borough');

        $this->assertSame('jane.smith@londonhotelgroup.co.uk', $croydon->fresh()->manager_email);
    }

    public function test_accommodation_totals_recalculate(): void
    {
        $croydon = $this->croydon();

        $this->assertSame(339, $croydon->totalUnits());

        $this->actingAsUser($this->manager());

        $this->patchJson("/api/properties/{$croydon->id}/accommodation", [
            'accommodation' => ['singles' => 110],
        ])->assertOk()->assertJsonPath('totalUnits', 344);
    }

    public function test_a_large_accommodation_change_raises_a_flag(): void
    {
        $croydon = $this->croydon();

        $this->actingAsUser($this->manager());

        // 38 triples to 4 is a 34-unit, 89% drop.
        $this->patchJson("/api/properties/{$croydon->id}/accommodation", [
            'accommodation' => ['triples' => 4],
        ])->assertOk()->assertJsonCount(1, 'flags');

        $this->assertDatabaseHas('change_flags', [
            'property_id' => $croydon->id,
            'accommodation_key' => 'triples',
            'previous_value' => 38,
            'new_value' => 4,
            'resolution' => ChangeFlag::PENDING,
        ]);
    }

    public function test_a_small_change_raises_no_flag(): void
    {
        $croydon = $this->croydon();

        $this->actingAsUser($this->manager());

        // 105 to 100 is only 5 units and under half.
        $this->patchJson("/api/properties/{$croydon->id}/accommodation", [
            'accommodation' => ['singles' => 100],
        ])->assertOk()->assertJsonCount(0, 'flags');
    }

    public function test_first_time_entry_from_zero_is_never_flagged(): void
    {
        $croydon = $this->croydon();

        $this->actingAsUser($this->manager());

        // house5 starts unset — recording 60 is data entry, not a correction.
        $this->patchJson("/api/properties/{$croydon->id}/accommodation", [
            'accommodation' => ['house5' => 60],
        ])->assertOk()->assertJsonCount(0, 'flags');
    }

    public function test_a_flag_can_be_reverted_and_does_not_re_flag(): void
    {
        $croydon = $this->croydon();

        $this->actingAsUser($this->manager());

        $response = $this->patchJson("/api/properties/{$croydon->id}/accommodation", [
            'accommodation' => ['triples' => 4],
        ])->assertOk();

        $flagId = $response->json('flags.0.id');

        $reverted = $this->postJson("/api/properties/{$croydon->id}/flags/{$flagId}/resolve", [
            'action' => 'revert',
        ])->assertOk();

        // Back to 38, and reverting did not raise a fresh flag of its own.
        $this->assertSame(38, $reverted->json('accommodation.triples'));
        $this->assertCount(0, $reverted->json('flags'));

        $this->assertDatabaseHas('change_flags', [
            'id' => $flagId,
            'resolution' => ChangeFlag::REVERTED,
        ]);
    }

    public function test_a_flag_can_be_confirmed(): void
    {
        $croydon = $this->croydon();

        $this->actingAsUser($this->manager());

        $flagId = $this->patchJson("/api/properties/{$croydon->id}/accommodation", [
            'accommodation' => ['triples' => 4],
        ])->json('flags.0.id');

        $confirmed = $this->postJson("/api/properties/{$croydon->id}/flags/{$flagId}/resolve", [
            'action' => 'confirm',
        ])->assertOk();

        $this->assertSame(4, $confirmed->json('accommodation.triples'));
        $this->assertCount(0, $confirmed->json('flags'));

        $this->assertDatabaseHas('change_flags', [
            'id' => $flagId,
            'resolution' => ChangeFlag::CONFIRMED,
        ]);
    }

    public function test_lifts_and_stairs_can_be_added_and_removed(): void
    {
        $croydon = $this->croydon();

        $this->actingAsUser($this->manager());

        $lift = $this->postJson("/api/properties/{$croydon->id}/elevators", [
            'name' => 'Lift C', 'type' => 'Goods', 'capacity' => 20,
            'width' => 1.6, 'accessible' => 'No',
        ])->assertCreated()->json();

        $this->assertSame('Lift C', $lift['name']);
        $this->assertSame(3, $croydon->fresh()->elevators()->count());

        $this->patchJson("/api/properties/{$croydon->id}/elevators/{$lift['id']}", [
            'capacity' => 24,
        ])->assertOk()->assertJsonPath('capacity', 24);

        $this->deleteJson("/api/properties/{$croydon->id}/elevators/{$lift['id']}")->assertOk();
        $this->assertSame(2, $croydon->fresh()->elevators()->count());

        $stair = $this->postJson("/api/properties/{$croydon->id}/staircases", [
            'name' => 'Stair 3', 'location' => 'West core',
            'floors_served' => 8, 'classification' => 'Emergency', 'emergency_exit' => 'Yes',
        ])->assertCreated()->json();

        $this->assertSame(3, $croydon->fresh()->staircases()->count());

        $this->deleteJson("/api/properties/{$croydon->id}/staircases/{$stair['id']}")->assertOk();
        $this->assertSame(2, $croydon->fresh()->staircases()->count());
    }

    public function test_a_lift_from_another_property_cannot_be_touched(): void
    {
        $croydon = $this->croydon();
        $otherLift = Property::where('site_name', 'Lewisham Lodge Hotel')
            ->firstOrFail()->elevators()->first();

        $this->actingAsUser($this->admin());

        $this->patchJson("/api/properties/{$croydon->id}/elevators/{$otherLift->id}", [
            'capacity' => 99,
        ])->assertNotFound();

        $this->assertSame(10, $otherLift->fresh()->capacity);
    }
}
