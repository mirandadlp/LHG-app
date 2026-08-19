<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportExportTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_report_returns_rows_and_a_company_total(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->getJson('/api/reports')->assertOk();

        $this->assertCount(7, $response->json('rows'));
        $this->assertSame(1243, $response->json('totals.Total units'));
        $this->assertSame('Company total', $response->json('totals.Site'));
        $this->assertSame(1243, $response->json('unitCount'));
    }

    public function test_columns_can_be_chosen_and_are_respected(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->getJson('/api/reports?columns=Site,Borough,Total units')->assertOk();

        $this->assertSame(['Site', 'Borough', 'Total units'], $response->json('columns'));
        $this->assertSame(['Site', 'Borough', 'Total units'], array_keys($response->json('rows.0')));
    }

    public function test_an_unknown_column_is_ignored_rather_than_trusted(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->getJson('/api/reports?columns=Site,DROP TABLE properties')->assertOk();

        $this->assertSame(['Site'], $response->json('columns'));
        $this->assertDatabaseCount('properties', 7);
    }

    public function test_filters_narrow_the_report_and_its_totals(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->getJson('/api/reports?borough=Croydon')->assertOk();

        $this->assertCount(1, $response->json('rows'));
        $this->assertSame(339, $response->json('totals.Total units'));
        $this->assertTrue($response->json('filterActive'));
    }

    public function test_a_manager_only_ever_reports_on_their_own_properties(): void
    {
        $this->actingAsUser($this->manager());

        $response = $this->getJson('/api/reports')->assertOk();

        $this->assertCount(1, $response->json('rows'));
        $this->assertSame(339, $response->json('totals.Total units'));
    }

    public function test_csv_export_downloads_with_a_total_row(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->get('/api/reports/export/csv')->assertOk();

        $response->assertHeader('Content-Type', 'text/csv; charset=UTF-8');

        $body = $response->getContent();

        $this->assertStringContainsString('Site', $body);
        $this->assertStringContainsString('Croydon Housing', $body);
        $this->assertStringContainsString('Company total', $body);
        // UTF-8 BOM so Excel on Windows reads m² correctly.
        $this->assertStringStartsWith("\xEF\xBB\xBF", $body);
    }

    public function test_excel_export_produces_a_real_workbook(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->get('/api/reports/export/xlsx')->assertOk();

        $body = $response->getContent();

        // XLSX files are ZIP archives — check the magic bytes.
        $this->assertStringStartsWith("PK\x03\x04", $body);
        $this->assertGreaterThan(3000, strlen($body));
    }

    public function test_pdf_export_produces_a_real_pdf(): void
    {
        $this->actingAsUser($this->admin());

        $response = $this->get('/api/reports/export/pdf')->assertOk();

        $body = $response->getContent();

        $this->assertStringStartsWith('%PDF-', $body);
        $this->assertGreaterThan(2000, strlen($body));
    }

    public function test_export_scope_all_ignores_the_active_filter(): void
    {
        $this->actingAsUser($this->admin());

        $filtered = $this->get('/api/reports/export/csv?borough=Croydon')->getContent();
        $everything = $this->get('/api/reports/export/csv?borough=Croydon&scope=all')->getContent();

        $this->assertStringNotContainsString('Lewisham Lodge Hotel', $filtered);
        $this->assertStringContainsString('Lewisham Lodge Hotel', $everything);
    }

    public function test_an_unsupported_format_is_a_404(): void
    {
        $this->actingAsUser($this->admin());

        $this->get('/api/reports/export/docx')->assertNotFound();
    }

    public function test_leadership_can_export_what_it_can_see(): void
    {
        $this->actingAsUser($this->leadership());

        $this->get('/api/reports/export/csv')->assertOk();
    }
}
