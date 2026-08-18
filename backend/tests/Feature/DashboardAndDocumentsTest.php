<?php

namespace Tests\Feature;

use App\Models\Property;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class DashboardAndDocumentsTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    protected $seeder = DatabaseSeeder::class;

    public function test_the_dashboard_totals_match_the_seeded_portfolio(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->getJson('/api/dashboard')->assertOk();

        $this->assertSame(7, $response->json('totals.properties'));
        $this->assertSame(1243, $response->json('totals.units'));
        $this->assertSame(12, $response->json('totals.lifts'));
        $this->assertSame(2, $response->json('totals.verified'));
        $this->assertSame(5, $response->json('totals.awaiting'));

        // Boroughs are ordered by unit count, largest first.
        $this->assertSame('Croydon', $response->json('byBorough.0.name'));
        $this->assertSame(339, $response->json('byBorough.0.units'));
    }

    public function test_dashboard_figures_follow_the_active_filter(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->getJson('/api/dashboard?region=London South')->assertOk();

        // Croydon, Lewisham and Greenwich.
        $this->assertSame(3, $response->json('totals.properties'));
        $this->assertSame(339 + 193 + 148, $response->json('totals.units'));
        $this->assertTrue($response->json('filterActive'));
    }

    public function test_a_manager_dashboard_covers_only_their_own_properties(): void
    {
        $this->actingAsUser($this->manager());

        $response = $this->getJson('/api/dashboard')->assertOk();

        $this->assertSame(1, $response->json('totals.properties'));
        $this->assertSame(339, $response->json('totals.units'));
    }

    public function test_needs_attention_surfaces_incomplete_and_overdue_records(): void
    {
        $this->actingAsUser($this->admin());

        $names = collect($this->getJson('/api/dashboard')->json('needsAttention'))
            ->pluck('siteName');

        $this->assertContains('Camden Row Residences', $names);  // Not Started
        $this->assertContains('Barking Gateway House', $names);  // Overdue
        $this->assertContains('Ealing Park Hostel', $names);     // Changes Requested
        $this->assertNotContains('Greenwich Court Apartments', $names);
    }

    public function test_a_document_can_be_uploaded_and_downloaded(): void
    {
        Storage::fake('local');

        $this->actingAsUser($this->manager());

        $croydon = $this->croydon();

        $document = $this->post("/api/properties/{$croydon->id}/documents", [
            'file' => UploadedFile::fake()->create('survey-2026.pdf', 120, 'application/pdf'),
            'type' => 'Property Survey',
            'notes' => 'Measured with a laser.',
        ])->assertCreated()->json();

        $this->assertSame('survey-2026.pdf', $document['name']);
        $this->assertSame('Property Survey', $document['type']);
        $this->assertSame('Jane Smith', $document['by']);

        $stored = $croydon->documents()->latest('id')->first();
        Storage::disk('local')->assertExists($stored->path);

        $this->get("/api/documents/{$stored->id}/download")
            ->assertOk()
            ->assertHeader('content-disposition', 'attachment; filename=survey-2026.pdf');

        $this->assertDatabaseHas('change_logs', [
            'property_id' => $croydon->id,
            'field' => 'Documents',
            'reason' => 'Uploaded survey-2026.pdf',
        ]);
    }

    public function test_an_executable_upload_is_refused(): void
    {
        Storage::fake('local');

        $this->actingAsUser($this->manager());

        $this->post("/api/properties/{$this->croydon()->id}/documents", [
            'file' => UploadedFile::fake()->create('payload.php', 10, 'application/x-php'),
            'type' => 'Floor Plan',
        ])->assertStatus(422)->assertJsonValidationErrors('file');
    }

    public function test_documents_are_not_readable_across_properties(): void
    {
        Storage::fake('local');

        $this->actingAsUser($this->admin());

        $lewisham = Property::where('site_name', 'Lewisham Lodge Hotel')->firstOrFail();

        $document = $this->post("/api/properties/{$lewisham->id}/documents", [
            'file' => UploadedFile::fake()->create('private.pdf', 10, 'application/pdf'),
            'type' => 'Certificate',
        ])->assertCreated()->json();

        // Jane manages Croydon, not Lewisham.
        $this->actingAsUser($this->manager());

        $this->get("/api/documents/{$document['id']}/download")->assertForbidden();
    }

    public function test_a_document_can_be_removed(): void
    {
        Storage::fake('local');

        $this->actingAsUser($this->manager());

        $croydon = $this->croydon();

        $document = $this->post("/api/properties/{$croydon->id}/documents", [
            'file' => UploadedFile::fake()->create('old-plan.pdf', 10, 'application/pdf'),
            'type' => 'Floor Plan',
        ])->assertCreated()->json();

        $path = $croydon->documents()->latest('id')->first()->path;

        $this->deleteJson("/api/properties/{$croydon->id}/documents/{$document['id']}")->assertOk();

        $this->assertDatabaseMissing('property_documents', ['id' => $document['id']]);
        Storage::disk('local')->assertMissing($path);
    }
}
