<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DocumentResource;
use App\Models\OptionListItem;
use App\Models\Property;
use App\Models\PropertyDocument;
use App\Services\PropertyWriter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\StreamedResponse;

class DocumentController extends Controller
{
    public function __construct(private readonly PropertyWriter $writer) {}

    public function store(Request $request, Property $property): JsonResponse
    {
        $this->authorize('manageDocuments', $property);

        $types = OptionListItem::where('list_key', 'documentTypes')->pluck('value')->all();

        $validated = $request->validate([
            'file' => [
                'required', 'file',
                'max:'.config('hub.max_document_upload_kb'),
                'mimes:'.implode(',', config('hub.allowed_document_mimes')),
            ],
            'type' => ['required', Rule::in($types ?: ['Floor Plan'])],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $file = $validated['file'];
        $disk = config('hub.documents_disk');

        // Stored under a per-property directory with a generated name; the
        // original filename is kept as a label, never as a path.
        $path = $file->store("properties/{$property->id}/documents", $disk);

        $document = $property->documents()->create([
            'name' => $file->getClientOriginalName(),
            'type' => $validated['type'],
            'disk' => $disk,
            'path' => $path,
            'mime_type' => $file->getClientMimeType(),
            'size_bytes' => $file->getSize(),
            'notes' => $validated['notes'] ?? null,
            'uploaded_by' => $request->user()->id,
            'uploaded_by_name' => $request->user()->name,
        ]);

        $count = $property->documents()->count();

        $this->writer->logStructural(
            $property, 'Documents', (string) ($count - 1), (string) $count,
            $request->user(), 'Uploaded '.$document->name,
        );

        return (new DocumentResource($document))->response()->setStatusCode(201);
    }

    public function download(Request $request, PropertyDocument $document): StreamedResponse
    {
        $this->authorize('view', $document->property);

        $disk = Storage::disk($document->disk);

        abort_unless($disk->exists($document->path), 404, 'That file is no longer stored.');

        return $disk->download($document->path, $document->name);
    }

    public function destroy(Request $request, Property $property, PropertyDocument $document): JsonResponse
    {
        $this->authorize('manageDocuments', $property);

        abort_unless($document->property_id === $property->id, 404);

        $before = $property->documents()->count();
        $name = $document->name;
        $document->delete();

        $this->writer->logStructural(
            $property, 'Documents', (string) $before, (string) ($before - 1),
            $request->user(), 'Removed '.$name,
        );

        return response()->json(['message' => "{$name} removed."]);
    }
}
