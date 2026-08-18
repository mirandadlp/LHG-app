<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PropertySummaryResource;
use App\Models\Property;
use App\Models\User;
use App\Services\PropertyWriter;
use App\Services\SpreadsheetImporter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;

/**
 * Bringing legacy spreadsheets into the central record.
 *
 * The flow is deliberately two-step: upload to get a preview with the mapping
 * and every problem spelled out, then commit only what the user confirmed.
 */
class ImportController extends Controller
{
    public function __construct(
        private readonly SpreadsheetImporter $importer,
        private readonly PropertyWriter $writer,
    ) {}

    /** Step one: parse the file and propose a column mapping. */
    public function preview(Request $request): JsonResponse
    {
        $request->validate([
            'file' => ['required', 'file', 'max:10240', 'mimes:xlsx,xls,csv,txt'],
        ]);

        $parsed = $this->importer->parse($request->file('file'));

        if ($parsed['rows'] === []) {
            return response()->json([
                'message' => 'That file has no rows to import.',
            ], 422);
        }

        return response()->json([
            'fileName' => $request->file('file')->getClientOriginalName(),
            'headers' => $parsed['headers'],
            'rows' => $parsed['rows'],
            'mapping' => $parsed['mapping'],
            'targets' => $this->importer->targets(),
            'preview' => $this->importer->preview($parsed['rows'], $parsed['mapping']),
        ]);
    }

    /** Re-run the preview after the user has corrected the mapping. */
    public function remap(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'rows' => ['required', 'array', 'max:5000'],
            'mapping' => ['required', 'array'],
            'mapping.*' => ['nullable', 'string', 'max:64'],
        ]);

        return response()->json([
            'preview' => $this->importer->preview($validated['rows'], $validated['mapping']),
        ]);
    }

    /** Step two: write the confirmed rows. */
    public function commit(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'rows' => ['required', 'array', 'min:1', 'max:5000'],
            'mapping' => ['required', 'array'],
            'fileName' => ['nullable', 'string', 'max:255'],
        ]);

        $preview = $this->importer->preview($validated['rows'], $validated['mapping']);
        $importable = array_filter($preview, fn ($row) => $row['importable']);

        if ($importable === []) {
            return response()->json([
                'message' => 'Nothing in this file can be imported. Every row is either a duplicate or has no site name.',
            ], 422);
        }

        $source = $validated['fileName'] ?? 'a legacy spreadsheet';
        $created = [];

        DB::transaction(function () use ($importable, $request, $source, &$created) {
            foreach ($importable as $row) {
                $values = $row['values'];

                $property = new Property([
                    'verification_status' => Property::STATUS_NOT_STARTED,
                    'created_by' => $request->user()->id,
                ]);
                $property->site_name = $values['siteName'];
                $property->operational_status = $values['operationalStatus'] ?? 'Open';
                $property->save();

                $this->writer->applyValues($property, $values, $request->user(), "Imported from {$source}");

                if ($row['accommodation'] !== []) {
                    $this->writer->applyAccommodation(
                        $property,
                        $row['accommodation'],
                        $request->user(),
                        "Imported from {$source}",
                        detectLargeChanges: false,
                    );
                }

                $this->writer->logStructural(
                    $property, 'Property record', '—', 'Imported',
                    $request->user(), "Imported from {$source}",
                );

                // Imported records start Not Started — nothing has been verified
                // by a human yet, whatever the spreadsheet claimed. This runs
                // last because writing values marks a record as In Progress.
                $property->forceFill(['verification_status' => Property::STATUS_NOT_STARTED])->save();

                $created[] = $property->id;
            }
        });

        $properties = Property::with(['accommodation', 'elevators', 'staircases', 'documents', 'changeLogs', 'changeFlags', 'fieldValues.fieldDefinition'])
            ->whereIn('id', $created)
            ->get();

        return response()->json([
            'message' => count($created).' '.str('property')->plural(count($created)).' imported.',
            'imported' => PropertySummaryResource::collection($properties),
            'skipped' => count($preview) - count($importable),
        ], 201);
    }

    /** Download a sample legacy file so the flow can be tried before it matters. */
    public function sample(): Response
    {
        return response($this->importer->sampleWorkbook(), 200, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition' => 'attachment; filename="legacy-property-spreadsheet.xlsx"',
            'X-Filename' => 'legacy-property-spreadsheet.xlsx',
        ]);
    }
}
