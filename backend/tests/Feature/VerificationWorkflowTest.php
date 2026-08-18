<?php

namespace Tests\Feature;

use App\Models\ChangeLog;
use App\Models\Property;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The verification round: manager fills the record in, submits it, corporate
 * approves it or sends it back. This is the process the whole app exists for.
 */
class VerificationWorkflowTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    protected $seeder = DatabaseSeeder::class;

    public function test_submitting_is_blocked_while_required_fields_are_missing(): void
    {
        $camden = Property::where('site_name', 'Camden Row Residences')->firstOrFail();
        $camden->update(['manager_id' => $this->manager()->id]);

        $this->actingAsUser($this->admin());

        $response = $this->postJson("/api/properties/{$camden->id}/submit")
            ->assertStatus(422)
            ->assertJsonStructure(['message', 'missing']);

        $this->assertNotEmpty($response->json('missing'));
        $this->assertSame(Property::STATUS_NOT_STARTED, $camden->fresh()->verification_status);
    }

    public function test_a_complete_record_can_be_submitted_and_approved(): void
    {
        $croydon = $this->croydon();

        // Croydon is missing nothing except the fields we top up here.
        $this->actingAsUser($this->manager());

        $missing = $croydon->missingFields()['required'];

        $values = [];

        foreach ($missing as $field) {
            $values[$field['key']] = match ($field['key']) {
                'managerEmail' => 'jane.smith@londonhotelgroup.co.uk',
                'postcode' => 'CR0 2TB',
                default => 'Yes',
            };
        }

        if ($values !== []) {
            $this->patchJson("/api/properties/{$croydon->id}", ['values' => $values])->assertOk();
        }

        $this->postJson("/api/properties/{$croydon->id}/submit")
            ->assertOk()
            ->assertJsonPath('verification', Property::STATUS_SUBMITTED);

        $this->assertNotNull($croydon->fresh()->submitted_at);

        // Corporate approves.
        $this->actingAsUser($this->admin());

        $this->postJson("/api/properties/{$croydon->id}/approve", [
            'comment' => 'Checked against the 2026 survey.',
        ])->assertOk()->assertJsonPath('verification', Property::STATUS_VERIFIED);

        $fresh = $croydon->fresh();

        $this->assertNotNull($fresh->verified_at);
        $this->assertSame($this->admin()->id, $fresh->verified_by);
        $this->assertNotNull($fresh->verification_due_on);

        // Approving the record approves the edits that made it up.
        $this->assertSame(
            0,
            ChangeLog::where('property_id', $croydon->id)
                ->where('approval_status', ChangeLog::PENDING)
                ->count(),
        );
    }

    public function test_corporate_can_send_a_submission_back(): void
    {
        $newham = Property::where('site_name', 'Newham Riverside House')->firstOrFail();

        $this->actingAsUser($this->admin());

        $this->postJson("/api/properties/{$newham->id}/request-changes", [
            'comment' => 'Room dimensions still missing.',
        ])->assertOk()->assertJsonPath('verification', Property::STATUS_CHANGES_REQUESTED);

        $this->assertNull($newham->fresh()->submitted_at);

        $this->assertDatabaseHas('change_logs', [
            'property_id' => $newham->id,
            'field' => 'Verification',
            'new_value' => Property::STATUS_CHANGES_REQUESTED,
            'reason' => 'Room dimensions still missing.',
        ]);
    }

    public function test_requesting_verification_starts_a_new_round(): void
    {
        $barking = Property::where('site_name', 'Barking Gateway House')->firstOrFail();

        $this->actingAsUser($this->admin());

        $this->postJson("/api/properties/{$barking->id}/request-verification")
            ->assertOk()
            ->assertJsonPath('verification', Property::STATUS_IN_PROGRESS);

        $this->assertNotNull($barking->fresh()->verification_due_on);
    }

    public function test_editing_a_not_started_record_moves_it_to_in_progress(): void
    {
        $camden = Property::where('site_name', 'Camden Row Residences')->firstOrFail();

        $this->assertSame(Property::STATUS_NOT_STARTED, $camden->verification_status);

        $this->actingAsUser($this->admin());

        $this->patchJson("/api/properties/{$camden->id}", [
            'values' => ['floors' => 4],
        ])->assertOk()->assertJsonPath('verification', Property::STATUS_IN_PROGRESS);
    }

    /**
     * The comment is optional, so the key is simply absent from the request
     * when a reviewer approves without typing anything. That path is the one
     * a busy administrator takes most often.
     */
    public function test_approving_without_a_comment_works(): void
    {
        $newham = Property::where('site_name', 'Newham Riverside House')->firstOrFail();

        $this->actingAsUser($this->admin());

        // No body at all.
        $this->postJson("/api/properties/{$newham->id}/approve")
            ->assertOk()
            ->assertJsonPath('verification', Property::STATUS_VERIFIED);

        $this->assertDatabaseHas('change_logs', [
            'property_id' => $newham->id,
            'field' => 'Verification',
            'new_value' => Property::STATUS_VERIFIED,
            'reason' => 'Approved by corporate',
        ]);
    }

    public function test_requesting_changes_without_a_comment_works(): void
    {
        $newham = Property::where('site_name', 'Newham Riverside House')->firstOrFail();

        $this->actingAsUser($this->admin());

        $this->postJson("/api/properties/{$newham->id}/request-changes")
            ->assertOk()
            ->assertJsonPath('verification', Property::STATUS_CHANGES_REQUESTED);

        $this->assertDatabaseHas('change_logs', [
            'property_id' => $newham->id,
            'reason' => 'Changes requested by corporate',
        ]);
    }

    /** An empty comment box means the same thing as no comment at all. */
    public function test_a_blank_comment_falls_back_to_the_default_wording(): void
    {
        $newham = Property::where('site_name', 'Newham Riverside House')->firstOrFail();

        $this->actingAsUser($this->admin());

        $this->postJson("/api/properties/{$newham->id}/approve", ['comment' => '   '])
            ->assertOk();

        $this->assertDatabaseHas('change_logs', [
            'property_id' => $newham->id,
            'reason' => 'Approved by corporate',
        ]);
    }

    public function test_a_property_cannot_be_submitted_twice(): void
    {
        $newham = Property::where('site_name', 'Newham Riverside House')->firstOrFail();

        $this->assertSame(Property::STATUS_SUBMITTED, $newham->verification_status);

        $this->actingAsUser($this->admin());

        $this->postJson("/api/properties/{$newham->id}/submit")->assertForbidden();
    }
}
