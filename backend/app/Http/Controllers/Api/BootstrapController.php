<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\FieldDefinition;
use App\Models\OptionListItem;
use App\Models\Property;
use App\Services\ReportBuilder;
use App\Support\AccommodationRegistry;
use App\Support\FieldRegistry;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Everything the app needs to render before it has loaded any property: the
 * signed-in user, the field registry, the controlled lists and the accommodation
 * model. One request instead of five on cold start.
 */
class BootstrapController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        return response()->json([
            'user' => new UserResource($request->user()),
            'sections' => FieldRegistry::SECTIONS,
            'fields' => FieldDefinition::activeDefinitions(),
            'options' => OptionListItem::grouped(),
            'accommodationTypes' => AccommodationRegistry::descriptors(),
            'accommodationGroups' => AccommodationRegistry::GROUPS,
            'verificationStatuses' => Property::STATUSES,
            'measurementUnits' => ['m²', 'ft²', 'm', 'ft'],
            'reportColumns' => ReportBuilder::ALL_COLUMNS,
            'defaultReportColumns' => ReportBuilder::DEFAULT_COLUMNS,
            'serverTime' => now()->toIso8601String(),
        ]);
    }
}
