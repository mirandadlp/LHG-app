<?php

namespace Tests\Feature;

use App\Models\Property;
use App\Services\SpreadsheetImporter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class ImportTest extends TestCase
{
    use RefreshDatabase;

    private function sampleUpload(): UploadedFile
    {
        $binary = app(SpreadsheetImporter::class)->sampleWorkbook();
        $path = tempnam(sys_get_temp_dir(), 'import').'.xlsx';
        file_put_contents($path, $binary);

        return new UploadedFile($path, 'legacy.xlsx', null, null, true);
    }

    public function test_the_sample_workbook_downloads(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->get('/api/import/sample')->assertOk();

        $this->assertStringStartsWith("PK\x03\x04", $response->getContent());
    }

    public function test_a_spreadsheet_is_parsed_and_columns_auto_mapped(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->post('/api/import/preview', ['file' => $this->sampleUpload()])
            ->assertOk();

        $this->assertCount(3, $response->json('rows'));
        $this->assertSame('siteName', $response->json('mapping.Site Name'));
        $this->assertSame('borough', $response->json('mapping.Borough'));
        $this->assertSame('accom:singles', $response->json('mapping.Singles'));
        $this->assertSame('accom:flat1', $response->json('mapping.1 Bedroom Flats'));
    }

    public function test_the_preview_flags_duplicates_before_anything_is_written(): void
    {
        $this->actingAsUser($this->admin());

        $preview = $this->post('/api/import/preview', ['file' => $this->sampleUpload()])
            ->assertOk()->json('preview');

        $byName = collect($preview)->keyBy(fn ($row) => $row['values']['siteName']);

        // Croydon Housing is already in the system.
        $this->assertTrue($byName['Croydon Housing']['duplicate']);
        $this->assertFalse($byName['Croydon Housing']['importable']);

        $this->assertFalse($byName['Hackney Wick House']['duplicate']);
        $this->assertTrue($byName['Hackney Wick House']['importable']);

        // Nothing has been written yet.
        $this->assertDatabaseCount('properties', 7);
    }

    public function test_committing_creates_only_the_importable_rows(): void
    {
        $this->actingAsUser($this->admin());

        $parsed = $this->post('/api/import/preview', ['file' => $this->sampleUpload()])->json();

        $response = $this->postJson('/api/import/commit', [
            'rows' => $parsed['rows'],
            'mapping' => $parsed['mapping'],
            'fileName' => 'legacy.xlsx',
        ])->assertCreated();

        // Two new properties; Croydon Housing skipped as a duplicate.
        $this->assertSame(1, $response->json('skipped'));
        $this->assertDatabaseCount('properties', 9);

        $hackney = Property::where('site_name', 'Hackney Wick House')->firstOrFail();

        $this->assertSame('Newham', $hackney->borough);
        $this->assertSame('E9 5LN', $hackney->postcode);
        $this->assertSame(44 + 26 + 8 + 12, $hackney->totalUnits());

        // Imported records are never presumed verified.
        $this->assertSame(Property::STATUS_NOT_STARTED, $hackney->verification_status);

        $this->assertDatabaseHas('change_logs', [
            'property_id' => $hackney->id,
            'field' => 'Property record',
            'new_value' => 'Imported',
            'reason' => 'Imported from legacy.xlsx',
        ]);
    }

    public function test_a_corrected_mapping_changes_the_preview(): void
    {
        $this->actingAsUser($this->admin());

        $parsed = $this->post('/api/import/preview', ['file' => $this->sampleUpload()])->json();

        $mapping = $parsed['mapping'];
        // Operator decides the "Singles" column actually held doubles, and
        // clears the real Doubles column so it is not double-counted.
        $mapping['Singles'] = 'accom:doubles';
        $mapping['Doubles'] = '';

        $preview = $this->postJson('/api/import/remap', [
            'rows' => $parsed['rows'],
            'mapping' => $mapping,
        ])->assertOk()->json('preview');

        $hackney = collect($preview)->firstWhere('values.siteName', 'Hackney Wick House');

        $this->assertSame(44, $hackney['accommodation']['doubles']);
        $this->assertArrayNotHasKey('singles', $hackney['accommodation']);
    }

    public function test_a_non_admin_cannot_import(): void
    {
        $this->actingAsUser($this->manager());

        $this->post('/api/import/preview', ['file' => $this->sampleUpload()])->assertForbidden();
        $this->assertDatabaseCount('properties', 7);
    }

    public function test_a_file_that_is_not_a_spreadsheet_is_rejected(): void
    {
        $this->actingAsUser($this->admin());

        $this->post('/api/import/preview', [
            'file' => UploadedFile::fake()->create('notes.pdf', 20, 'application/pdf'),
        ])->assertStatus(422)->assertJsonValidationErrors('file');
    }
}
