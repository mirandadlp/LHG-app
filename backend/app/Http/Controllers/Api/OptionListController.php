<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\OptionListItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Editing the controlled dropdown lists (boroughs, councils, regions, …). */
class OptionListController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['options' => OptionListItem::grouped()]);
    }

    public function store(Request $request, string $listKey): JsonResponse
    {
        $validated = $request->validate([
            'value' => ['required', 'string', 'max:120'],
        ]);

        abort_unless(
            array_key_exists($listKey, OptionListItem::grouped()),
            404,
            'Unknown list.',
        );

        OptionListItem::firstOrCreate(
            ['list_key' => $listKey, 'value' => trim($validated['value'])],
            ['sort_order' => (int) OptionListItem::where('list_key', $listKey)->max('sort_order') + 1],
        );

        return response()->json(['options' => OptionListItem::grouped()], 201);
    }

    public function destroy(string $listKey, string $value): JsonResponse
    {
        $deleted = OptionListItem::where('list_key', $listKey)
            ->where('value', urldecode($value))
            ->delete();

        abort_unless($deleted, 404, 'That option is not in the list.');

        return response()->json(['options' => OptionListItem::grouped()]);
    }
}
