<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FieldDefinition;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * The custom-field builder. Corporate adds what the business decides it needs
 * next and it appears on every property immediately — no rebuild, no release.
 */
class FieldDefinitionController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['fields' => FieldDefinition::activeDefinitions()]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'label' => ['required', 'string', 'max:120'],
            'section' => ['required', Rule::in(['general', 'dimensions', 'accessibility', 'building'])],
            'type' => ['required', Rule::in([
                'text', 'number', 'decimal', 'date', 'yesno', 'dropdown', 'measurement', 'notes',
            ])],
            'required' => ['boolean'],
            'help' => ['nullable', 'string', 'max:255'],
            'unit' => ['nullable', 'string', 'max:32'],
            'optionList' => ['nullable', 'array', 'max:100'],
            'optionList.*' => ['string', 'max:120'],
        ]);

        $definition = FieldDefinition::create([
            'key' => $this->uniqueKey($validated['label']),
            'section' => $validated['section'],
            'label' => $validated['label'],
            // "dropdown" is the word the builder shows; the storage type is
            // custom-select, which carries its own inline option list.
            'type' => $validated['type'] === 'dropdown' ? 'custom-select' : $validated['type'],
            'required' => $validated['required'] ?? false,
            'help' => $validated['help'] ?? null,
            'unit' => $validated['unit'] ?? null,
            'option_list' => $validated['optionList'] ?? null,
            'is_custom' => true,
            'sort_order' => (int) FieldDefinition::where('is_custom', true)->max('sort_order') + 1,
            'created_by' => $request->user()->id,
        ]);

        FieldDefinition::forgetCache();

        return response()->json([
            'message' => "\"{$definition->label}\" is now collected on every property record.",
            'fields' => FieldDefinition::activeDefinitions(),
        ], 201);
    }

    public function destroy(FieldDefinition $fieldDefinition): JsonResponse
    {
        // Base fields are part of the record's contract and cannot be removed.
        abort_unless($fieldDefinition->is_custom, 422, 'Base fields cannot be removed.');

        $label = $fieldDefinition->label;
        $fieldDefinition->delete(); // Cascades to every stored value.

        FieldDefinition::forgetCache();

        return response()->json([
            'message' => "\"{$label}\" removed from the record.",
            'fields' => FieldDefinition::activeDefinitions(),
        ]);
    }

    /** Stable, readable, collision-free key derived from the label. */
    private function uniqueKey(string $label): string
    {
        $base = 'cf_'.str($label)->slug('_')->limit(40, '')->toString();
        $key = $base;
        $suffix = 2;

        while (FieldDefinition::where('key', $key)->exists()) {
            $key = $base.'_'.$suffix++;
        }

        return $key;
    }
}
