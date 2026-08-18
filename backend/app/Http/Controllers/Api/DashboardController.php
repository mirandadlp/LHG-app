<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PropertySummaryResource;
use App\Models\Property;
use App\Services\ReportBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Every figure here is computed over the filtered, role-scoped set, so what the
 * dashboard shows always matches what the user can actually open.
 */
class DashboardController extends Controller
{
    public function __construct(private readonly ReportBuilder $reports) {}

    public function __invoke(Request $request): JsonResponse
    {
        $this->authorize('viewAny', Property::class);

        $properties = Property::query()
            ->with(['accommodation', 'elevators', 'staircases', 'documents', 'changeLogs', 'changeFlags', 'fieldValues.fieldDefinition'])
            ->visibleTo($request->user())
            ->filtered([
                'borough' => $request->query('borough'),
                'council' => $request->query('council'),
                'region' => $request->query('region'),
                'property_type' => $request->query('propertyType'),
                'verification' => $request->query('verification'),
                'q' => $request->query('q'),
            ])
            ->get();

        $aggregate = $this->reports->aggregate($properties);

        return response()->json([
            ...$aggregate,
            'needsAttention' => PropertySummaryResource::collection(
                $this->reports->needingAttention($properties)
            ),
            'filterActive' => collect(['borough', 'council', 'region', 'propertyType', 'verification', 'q'])
                ->contains(fn ($key) => filled($request->query($key))),
        ]);
    }
}
