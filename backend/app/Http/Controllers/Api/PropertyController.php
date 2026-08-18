<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StorePropertyRequest;
use App\Http\Requests\UpdatePropertyRequest;
use App\Http\Resources\PropertyResource;
use App\Http\Resources\PropertySummaryResource;
use App\Models\ChangeLog;
use App\Models\Property;
use App\Services\PropertyWriter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PropertyController extends Controller
{
    /** Relations every property screen reads. Eager-loaded to keep queries flat. */
    private const EAGER = [
        'accommodation', 'elevators', 'staircases', 'documents',
        'changeLogs', 'changeFlags', 'fieldValues.fieldDefinition', 'manager',
    ];

    public function __construct(private readonly PropertyWriter $writer) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize('viewAny', Property::class);

        $properties = Property::query()
            ->with(self::EAGER)
            ->visibleTo($request->user())
            ->filtered($this->filters($request))
            ->orderBy('site_name')
            ->get();

        return PropertySummaryResource::collection($properties);
    }

    public function show(Request $request, Property $property): PropertyResource
    {
        $this->authorize('view', $property);

        return new PropertyResource($property->load(self::EAGER));
    }

    public function store(StorePropertyRequest $request): JsonResponse
    {
        $this->authorize('create', Property::class);

        $property = new Property([
            'verification_status' => Property::STATUS_NOT_STARTED,
            'created_by' => $request->user()->id,
        ]);
        $property->site_name = $request->validated('values.siteName');
        $property->save();

        $this->writer->applyValues(
            $property,
            $request->validated('values'),
            $request->user(),
            'New property added',
        );

        $this->writer->logStructural(
            $property,
            'Property record',
            '—',
            'Created',
            $request->user(),
            'New property added',
        );

        return (new PropertyResource($property->fresh(self::EAGER)))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * Patch field values. The body carries only what changed, and anything that
     * does not actually differ from the stored value writes no audit row.
     */
    public function update(UpdatePropertyRequest $request, Property $property): PropertyResource
    {
        $this->authorize('update', $property);

        $this->writer->applyValues(
            $property,
            $request->validated('values'),
            $request->user(),
            $request->validated('reason'),
        );

        return new PropertyResource($property->fresh(self::EAGER));
    }

    public function destroy(Request $request, Property $property): JsonResponse
    {
        $this->authorize('delete', $property);

        $property->delete();

        return response()->json(['message' => "{$property->site_name} archived."]);
    }

    /**
     * Update accommodation counts. Returns any change flags raised so the client
     * can ask the property manager to confirm an unusually large movement.
     */
    public function updateAccommodation(Request $request, Property $property): PropertyResource
    {
        $this->authorize('update', $property);

        $validated = $request->validate([
            'accommodation' => ['required', 'array'],
            'accommodation.*' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'reason' => ['nullable', 'string', 'max:255'],
        ]);

        $this->writer->applyAccommodation(
            $property,
            $validated['accommodation'],
            $request->user(),
            $validated['reason'] ?? null,
        );

        return new PropertyResource($property->fresh(self::EAGER));
    }

    /* ------------------------------------------------------------------
     | Verification workflow
     ------------------------------------------------------------------ */

    /** Property manager sends the record to corporate for review. */
    public function submit(Request $request, Property $property): PropertyResource|JsonResponse
    {
        $this->authorize('submit', $property);

        $missing = $property->missingFields()['required'];

        if ($missing !== []) {
            return response()->json([
                'message' => 'Complete the required fields before submitting.',
                'missing' => $missing,
            ], 422);
        }

        $previous = $property->verification_status;

        $property->forceFill([
            'verification_status' => Property::STATUS_SUBMITTED,
            'submitted_at' => now(),
        ])->save();

        $this->writer->logVerification(
            $property,
            $previous,
            Property::STATUS_SUBMITTED,
            $request->user(),
            'Submitted for review by property manager',
        );

        return new PropertyResource($property->fresh(self::EAGER));
    }

    /** Corporate approves the submission. */
    public function approve(Request $request, Property $property): PropertyResource
    {
        $this->authorize('review', $property);

        $validated = $request->validate([
            'comment' => ['nullable', 'string', 'max:500'],
        ]);

        $previous = $property->verification_status;

        $property->forceFill([
            'verification_status' => Property::STATUS_VERIFIED,
            'verified_at' => now(),
            'verified_by' => $request->user()->id,
            'verification_due_on' => now()->addDays((int) config('hub.verification_interval_days'))->toDateString(),
        ])->save();

        $this->writer->logVerification(
            $property,
            $previous,
            Property::STATUS_VERIFIED,
            $request->user(),
            $validated['comment'] ?: 'Approved by corporate',
        );

        // Approving the record approves the edits that made it up.
        $property->changeLogs()
            ->where('approval_status', ChangeLog::PENDING)
            ->update([
                'approval_status' => ChangeLog::APPROVED,
                'approved_by' => $request->user()->id,
                'approved_at' => now(),
            ]);

        return new PropertyResource($property->fresh(self::EAGER));
    }

    /** Corporate sends it back with a comment. */
    public function requestChanges(Request $request, Property $property): PropertyResource
    {
        $this->authorize('review', $property);

        $validated = $request->validate([
            'comment' => ['nullable', 'string', 'max:500'],
        ]);

        $previous = $property->verification_status;

        $property->forceFill([
            'verification_status' => Property::STATUS_CHANGES_REQUESTED,
            'submitted_at' => null,
        ])->save();

        $this->writer->logVerification(
            $property,
            $previous,
            Property::STATUS_CHANGES_REQUESTED,
            $request->user(),
            $validated['comment'] ?: 'Changes requested by corporate',
        );

        return new PropertyResource($property->fresh(self::EAGER));
    }

    /** Corporate asks a manager to start a fresh verification round. */
    public function requestVerification(Request $request, Property $property): PropertyResource
    {
        $this->authorize('review', $property);

        $previous = $property->verification_status;

        $property->forceFill([
            'verification_status' => Property::STATUS_IN_PROGRESS,
            'verification_due_on' => now()->addDays(30)->toDateString(),
        ])->save();

        $this->writer->logVerification(
            $property,
            $previous,
            Property::STATUS_IN_PROGRESS,
            $request->user(),
            'Verification requested',
        );

        return new PropertyResource($property->fresh(self::EAGER));
    }

    /* ------------------------------------------------------------------
     | Helpers
     ------------------------------------------------------------------ */

    private function filters(Request $request): array
    {
        return [
            'borough' => $request->query('borough'),
            'council' => $request->query('council'),
            'region' => $request->query('region'),
            'property_type' => $request->query('propertyType'),
            'verification' => $request->query('verification'),
            'q' => $request->query('q'),
        ];
    }
}
