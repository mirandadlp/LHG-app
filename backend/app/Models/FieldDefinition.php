<?php

namespace App\Models;

use App\Support\FieldRegistry;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class FieldDefinition extends Model
{
    /** @var array<int, array<string, mixed>>|null */
    private static ?array $definitionCache = null;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'required' => 'boolean',
            'is_custom' => 'boolean',
            'option_list' => 'array',
        ];
    }

    public function values(): HasMany
    {
        return $this->hasMany(PropertyFieldValue::class);
    }

    /**
     * The complete field registry as the client sees it: the locked base fields
     * first, then whatever corporate has added since, in display order.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function activeDefinitions(): array
    {
        // Memoised for the lifetime of the request: completeness scoring calls
        // this once per property, and the registry cannot change mid-request.
        if (static::$definitionCache !== null) {
            return static::$definitionCache;
        }

        $base = array_map(fn ($field) => [
            // Base fields have no addressable row — they cannot be deleted.
            'definitionId' => null,
            'key' => $field['key'],
            'section' => $field['section'],
            'label' => $field['label'],
            'type' => $field['type'],
            'required' => $field['required'],
            'help' => $field['help'],
            'unit' => null,
            'optionListKey' => $field['optionListKey'],
            'optionList' => null,
            'custom' => false,
        ], FieldRegistry::baseFields());

        $custom = static::query()
            ->where('is_custom', true)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn (self $definition) => [
                'definitionId' => $definition->id,
                'key' => $definition->key,
                'section' => $definition->section,
                'label' => $definition->label,
                'type' => $definition->type,
                'required' => $definition->required,
                'help' => $definition->help,
                'unit' => $definition->unit,
                'optionListKey' => $definition->option_list_key,
                'optionList' => $definition->option_list,
                'custom' => true,
            ])
            ->all();

        return static::$definitionCache = [...$base, ...$custom];
    }

    /** Drop the memoised registry after a custom field is added or removed. */
    public static function forgetCache(): void
    {
        static::$definitionCache = null;
    }

    /** @return array<string, array<string, mixed>> */
    public static function activeByKey(): array
    {
        return array_column(static::activeDefinitions(), null, 'key');
    }
}
