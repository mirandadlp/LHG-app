<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\StaircaseResource;
use App\Models\Property;
use App\Models\Staircase;
use App\Services\PropertyWriter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class StaircaseController extends Controller
{
    public function __construct(private readonly PropertyWriter $writer) {}

    public function store(Request $request, Property $property): JsonResponse
    {
        $this->authorize('update', $property);

        $validated = $this->validated($request);
        $before = $property->staircases()->count();

        $staircase = $property->staircases()->create([
            ...$validated,
            'name' => $validated['name'] ?? 'Stair '.($before + 1),
            'position' => $before,
        ]);

        $this->writer->logStructural(
            $property, 'Staircases', (string) $before, (string) ($before + 1),
            $request->user(), 'Record added',
        );

        return (new StaircaseResource($staircase))->response()->setStatusCode(201);
    }

    public function update(Request $request, Property $property, Staircase $staircase): StaircaseResource
    {
        $this->authorize('update', $property);
        $this->assertBelongsTo($property, $staircase);

        $staircase->update($this->validated($request));

        return new StaircaseResource($staircase);
    }

    public function destroy(Request $request, Property $property, Staircase $staircase): JsonResponse
    {
        $this->authorize('update', $property);
        $this->assertBelongsTo($property, $staircase);

        $before = $property->staircases()->count();
        $staircase->delete();

        $this->writer->logStructural(
            $property, 'Staircases', (string) $before, (string) ($before - 1),
            $request->user(), 'Record removed',
        );

        return response()->json(['message' => 'Staircase removed.']);
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['nullable', 'string', 'max:255'],
            'location' => ['nullable', 'string', 'max:255'],
            'floors_served' => ['nullable', 'integer', 'min:0', 'max:200'],
            'width' => ['nullable', 'numeric', 'min:0', 'max:99'],
            'classification' => ['nullable', Rule::in([
                'Standard', 'Accessible', 'Emergency', 'Accessible & Emergency',
            ])],
            'emergency_exit' => ['nullable', Rule::in(['Yes', 'No'])],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);
    }

    private function assertBelongsTo(Property $property, Staircase $staircase): void
    {
        abort_unless($staircase->property_id === $property->id, 404);
    }
}
