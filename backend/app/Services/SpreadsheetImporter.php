<?php

namespace App\Services;

use App\Models\Property;
use App\Support\AccommodationRegistry;
use App\Support\FieldRegistry;
use Illuminate\Http\UploadedFile;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

/**
 * Reads a legacy spreadsheet, guesses which column means which field, and
 * builds a preview. Nothing is written to the database until the preview comes
 * back confirmed — an import that silently created 400 wrong records would be
 * far worse than one that needed a second click.
 */
class SpreadsheetImporter
{
    /** Column headers can only map onto general fields and accommodation counts. */
    public function targets(): array
    {
        $targets = [];

        foreach (FieldRegistry::baseFields() as $field) {
            if ($field['section'] === 'general') {
                $targets[] = ['id' => $field['key'], 'label' => $field['label']];
            }
        }

        foreach (AccommodationRegistry::descriptors() as $type) {
            $targets[] = [
                'id' => 'accom:'.$type['key'],
                'label' => 'Accommodation — '.$type['label'],
            ];
        }

        return $targets;
    }

    /**
     * Parse the first sheet into headers + rows, and propose a mapping.
     *
     * @return array{headers: array<int, string>, rows: array<int, array<string, mixed>>, mapping: array<string, string>}
     */
    public function parse(UploadedFile $file): array
    {
        $reader = IOFactory::createReaderForFile($file->getRealPath());
        $reader->setReadDataOnly(true);

        $sheet = $reader->load($file->getRealPath())->getSheet(0);
        $grid = $sheet->toArray(null, true, true, false);

        if ($grid === []) {
            return ['headers' => [], 'rows' => [], 'mapping' => []];
        }

        $headers = array_values(array_map(
            fn ($cell) => trim((string) $cell),
            array_shift($grid),
        ));

        // Drop trailing unnamed columns produced by stray formatting.
        while ($headers !== [] && end($headers) === '') {
            array_pop($headers);
        }

        $rows = [];

        foreach ($grid as $line) {
            $row = [];
            $hasContent = false;

            foreach ($headers as $index => $header) {
                $value = $line[$index] ?? '';
                $value = is_string($value) ? trim($value) : $value;
                $row[$header] = $value;

                if ($value !== '' && $value !== null) {
                    $hasContent = true;
                }
            }

            if ($hasContent) {
                $rows[] = $row;
            }
        }

        return [
            'headers' => $headers,
            'rows' => $rows,
            'mapping' => $this->guessMapping($headers),
        ];
    }

    /**
     * Match headers to fields by normalised name. "Site Name", "site_name" and
     * "SITENAME" all land on siteName; anything unrecognised is left unmapped
     * for a human to decide.
     *
     * @param  array<int, string>  $headers
     * @return array<string, string>
     */
    public function guessMapping(array $headers): array
    {
        $targets = $this->targets();
        $mapping = [];

        foreach ($headers as $header) {
            $normalised = $this->normalise($header);
            $mapping[$header] = '';

            if ($normalised === '') {
                continue;
            }

            foreach ($targets as $target) {
                $targetNormalised = $this->normalise($target['label']);

                if ($targetNormalised === $normalised) {
                    $mapping[$header] = $target['id'];
                    break;
                }
            }

            if ($mapping[$header] !== '') {
                continue;
            }

            // Fall back to a containment match, longest label first so
            // "3 Bedroom Flats" beats "Flats".
            $candidates = $targets;
            usort($candidates, fn ($a, $b) => mb_strlen($b['label']) <=> mb_strlen($a['label']));

            foreach ($candidates as $target) {
                $targetNormalised = $this->normalise($target['label']);

                if ($targetNormalised !== ''
                    && (str_contains($targetNormalised, $normalised) || str_contains($normalised, $targetNormalised))) {
                    $mapping[$header] = $target['id'];
                    break;
                }
            }
        }

        return $mapping;
    }

    /**
     * Turn raw rows plus a mapping into preview entries, each carrying the
     * problems that would stop it importing.
     *
     * @param  array<int, array<string, mixed>>  $rows
     * @param  array<string, string>  $mapping
     * @return array<int, array<string, mixed>>
     */
    public function preview(array $rows, array $mapping): array
    {
        $existing = Property::pluck('site_name')
            ->map(fn ($name) => mb_strtolower(trim((string) $name)))
            ->flip();

        $requiredGeneral = array_filter(
            FieldRegistry::baseFields(),
            fn ($f) => $f['required'] && $f['section'] === 'general',
        );

        $seenInFile = [];
        $preview = [];

        foreach ($rows as $index => $row) {
            $values = [];
            $accommodation = [];

            foreach ($mapping as $header => $target) {
                if ($target === '' || ! array_key_exists($header, $row)) {
                    continue;
                }

                $raw = $row[$header];

                if (str_starts_with($target, 'accom:')) {
                    $key = substr($target, 6);
                    $accommodation[$key] = ($raw === '' || $raw === null) ? null : max(0, (int) $raw);

                    continue;
                }

                $values[$target] = ($raw === '' || $raw === null) ? null : $raw;
            }

            $siteName = trim((string) ($values['siteName'] ?? ''));
            $siteKey = mb_strtolower($siteName);

            $duplicateInSystem = $siteName !== '' && $existing->has($siteKey);
            $duplicateInFile = $siteName !== '' && isset($seenInFile[$siteKey]);

            if ($siteName !== '') {
                $seenInFile[$siteKey] = true;
            }

            $missing = [];

            foreach ($requiredGeneral as $field) {
                if (! Property::isFilled($values[$field['key']] ?? null)) {
                    $missing[] = $field['label'];
                }
            }

            $preview[] = [
                'index' => $index,
                'values' => $values,
                'accommodation' => $accommodation,
                'totalUnits' => array_sum(array_map(fn ($v) => (int) $v, $accommodation)),
                'duplicate' => $duplicateInSystem || $duplicateInFile,
                'duplicateReason' => match (true) {
                    $duplicateInSystem => 'Already in the system — will be skipped',
                    $duplicateInFile => 'Repeated earlier in this file — will be skipped',
                    default => null,
                },
                'missingRequired' => $missing,
                'importable' => $siteName !== '' && ! $duplicateInSystem && ! $duplicateInFile,
            ];
        }

        return $preview;
    }

    /** A demo legacy spreadsheet so the import flow can be tried end to end. */
    public function sampleWorkbook(): string
    {
        $demo = [
            ['Site Name', 'Address Line 1', 'City', 'Postal Code', 'Borough', 'Council',
                'Region', 'Property Type', 'General manager / property manager',
                'Singles', 'Doubles', 'Triples', '1 Bedroom Flats'],
            ['Hackney Wick House', '18 Wallis Road', 'London', 'E9 5LN', 'Newham',
                'Newham Council', 'London East', 'Temporary Accommodation', 'Leah Turner', 44, 26, 8, 12],
            ['Croydon Housing', '142 London Road', 'Croydon', 'CR0 2TB', 'Croydon',
                'Croydon Council', 'London South', 'Residential Housing', 'Jane Smith', 105, 72, 38, 0],
            ['Southwark Bridge Rooms', '4 Sumner Street', 'London', 'SE1 9JA', 'Lewisham',
                'Lewisham Council', 'London South', 'Hotel', '', 31, 40, 0, 0],
        ];

        $spreadsheet = new Spreadsheet;
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Legacy');
        $sheet->fromArray($demo, null, 'A1');
        $sheet->getStyle('A1:M1')->getFont()->setBold(true);

        foreach (range('A', 'M') as $column) {
            $sheet->getColumnDimension($column)->setAutoSize(true);
        }

        ob_start();
        (new Xlsx($spreadsheet))->save('php://output');
        $binary = ob_get_clean();

        $spreadsheet->disconnectWorksheets();

        return $binary;
    }

    private function normalise(string $value): string
    {
        return preg_replace('/[^a-z0-9]/', '', mb_strtolower($value)) ?? '';
    }
}
