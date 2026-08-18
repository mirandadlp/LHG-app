<?php

namespace Database\Seeders;

use App\Models\FieldDefinition;
use App\Models\User;
use App\Support\FieldRegistry;
use Illuminate\Database\Seeder;

/**
 * Mirrors the base registry into the database so the admin screen can list every
 * field, and seeds the one custom field the prototype shipped with.
 */
class FieldDefinitionSeeder extends Seeder
{
    public function run(): void
    {
        foreach (FieldRegistry::baseFields() as $index => $field) {
            FieldDefinition::updateOrCreate(
                ['key' => $field['key']],
                [
                    'section' => $field['section'],
                    'label' => $field['label'],
                    'type' => $field['type'],
                    'required' => $field['required'],
                    'help' => $field['help'],
                    'option_list_key' => $field['optionListKey'],
                    'is_custom' => false,
                    'sort_order' => $index,
                ],
            );
        }

        FieldDefinition::updateOrCreate(
            ['key' => 'cf_boilers'],
            [
                'section' => 'building',
                'label' => 'Number of boilers',
                'type' => 'number',
                'required' => false,
                'help' => 'Added by Corporate Admin, July 2026.',
                'is_custom' => true,
                'sort_order' => 1000,
                'created_by' => User::where('role', User::ROLE_ADMIN)->value('id'),
            ],
        );
    }
}
