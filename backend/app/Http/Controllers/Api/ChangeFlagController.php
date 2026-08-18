<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PropertyResource;
use App\Models\ChangeFlag;
use App\Models\Property;
use App\Services\PropertyWriter;
use Illuminate\Http\Request;

/**
 * Resolving a large-change flag: either the property manager confirms the new
 * figure is right, or they revert to what was there before.
 */
class ChangeFlagController extends Controller
{
    public function __construct(private readonly PropertyWriter $writer) {}

    public function resolve(Request $request, Property $property, ChangeFlag $flag): PropertyResource
    {
        $this->authorize('update', $property);

        abort_unless($flag->property_id === $property->id, 404);

        $validated = $request->validate([
            'action' => ['required', 'in:confirm,revert'],
        ]);

        if ($validated['action'] === 'revert') {
            // Put the old figure back, which writes its own audit row.
            $this->writer->applyAccommodation(
                $property,
                [$flag->accommodation_key => $flag->previous_value],
                $request->user(),
                'Reverted after large-change review',
                detectLargeChanges: false,
            );
        }

        $flag->forceFill([
            'resolution' => $validated['action'] === 'revert' ? ChangeFlag::REVERTED : ChangeFlag::CONFIRMED,
            'resolved_by' => $request->user()->id,
            'resolved_at' => now(),
        ])->save();

        return new PropertyResource($property->fresh([
            'accommodation', 'elevators', 'staircases', 'documents',
            'changeLogs', 'changeFlags', 'fieldValues.fieldDefinition',
        ]));
    }
}
