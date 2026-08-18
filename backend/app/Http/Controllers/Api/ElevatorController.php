<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ElevatorResource;
use App\Models\Elevator;
use App\Models\OptionListItem;
use App\Models\Property;
use App\Services\PropertyWriter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ElevatorController extends Controller
{
    public function __construct(private readonly PropertyWriter $writer) {}

    public function store(Request $request, Property $property): JsonResponse
    {
        $this->authorize('update', $property);

        $validated = $this->validated($request);
        $before = $property->elevators()->count();

        $elevator = $property->elevators()->create([
            ...$validated,
            'name' => $validated['name'] ?? 'Lift '.($before + 1),
            'position' => $before,
        ]);

        $this->writer->logStructural(
            $property, 'Elevators', (string) $before, (string) ($before + 1),
            $request->user(), 'Record added',
        );

        return (new ElevatorResource($elevator))->response()->setStatusCode(201);
    }

    public function update(Request $request, Property $property, Elevator $elevator): ElevatorResource
    {
        $this->authorize('update', $property);
        $this->assertBelongsTo($property, $elevator);

        $elevator->update($this->validated($request));

        return new ElevatorResource($elevator);
    }

    public function destroy(Request $request, Property $property, Elevator $elevator): JsonResponse
    {
        $this->authorize('update', $property);
        $this->assertBelongsTo($property, $elevator);

        $before = $property->elevators()->count();
        $elevator->delete();

        $this->writer->logStructural(
            $property, 'Elevators', (string) $before, (string) ($before - 1),
            $request->user(), 'Record removed',
        );

        return response()->json(['message' => 'Elevator removed.']);
    }

    private function validated(Request $request): array
    {
        $types = OptionListItem::where('list_key', 'elevatorTypes')->pluck('value')->all();

        return $request->validate([
            'name' => ['nullable', 'string', 'max:255'],
            'type' => ['nullable', Rule::in($types ?: ['Passenger', 'Service', 'Goods', 'Platform Lift'])],
            'capacity' => ['nullable', 'integer', 'min:0', 'max:500'],
            'max_occupancy' => ['nullable', 'integer', 'min:0', 'max:500'],
            'width' => ['nullable', 'numeric', 'min:0', 'max:99'],
            'depth' => ['nullable', 'numeric', 'min:0', 'max:99'],
            'height' => ['nullable', 'numeric', 'min:0', 'max:99'],
            'door_width' => ['nullable', 'numeric', 'min:0', 'max:99'],
            'accessible' => ['nullable', Rule::in(['Yes', 'No'])],
            'service' => ['nullable', Rule::in(['Yes', 'No'])],
            'passenger' => ['nullable', Rule::in(['Yes', 'No'])],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);
    }

    private function assertBelongsTo(Property $property, Elevator $elevator): void
    {
        abort_unless($elevator->property_id === $property->id, 404);
    }
}
