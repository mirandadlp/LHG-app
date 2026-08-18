<?php

namespace App\Http\Requests;

use App\Models\FieldDefinition;
use App\Models\OptionListItem;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * Validates a patch of field values.
 *
 * Rules are derived from the field registry rather than hardcoded, so a custom
 * field added by corporate this morning is validated correctly this afternoon.
 */
class UpdatePropertyRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Handled by PropertyPolicy in the controller.
    }

    public function rules(): array
    {
        return [
            'values' => ['required', 'array'],
            'reason' => ['nullable', 'string', 'max:255'],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                $definitions = FieldDefinition::activeByKey();
                $options = OptionListItem::grouped();

                foreach ((array) $this->input('values', []) as $key => $value) {
                    $definition = $definitions[$key] ?? null;

                    if (! $definition) {
                        $validator->errors()->add("values.{$key}", "Unknown field '{$key}'.");

                        continue;
                    }

                    $this->validateValue($validator, $key, $value, $definition, $options);
                }
            },
        ];
    }

    private function validateValue(
        Validator $validator,
        string $key,
        mixed $value,
        array $definition,
        array $options,
    ): void {
        $path = "values.{$key}";
        $label = $definition['label'];

        // Clearing a field is always allowed; required-ness is enforced at submit.
        if ($value === null || $value === '') {
            return;
        }

        switch ($definition['type']) {
            case 'number':
                if (! is_numeric($value) || (int) $value < 0) {
                    $validator->errors()->add($path, "{$label} must be a whole number of zero or more.");
                }
                break;

            case 'decimal':
                if (! is_numeric($value)) {
                    $validator->errors()->add($path, "{$label} must be a number.");
                }
                break;

            case 'date':
                if (! strtotime((string) $value)) {
                    $validator->errors()->add($path, "{$label} must be a valid date.");
                }
                break;

            case 'email':
                if (! filter_var($value, FILTER_VALIDATE_EMAIL)) {
                    $validator->errors()->add($path, "{$label} must be a valid email address.");
                }
                break;

            case 'postcode':
                if (! preg_match('/^[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}$/i', (string) $value)) {
                    $validator->errors()->add($path, "{$label} does not look like a UK postcode.");
                }
                break;

            case 'yesno':
                if (! in_array($value, ['Yes', 'No', 'N/A'], true)) {
                    $validator->errors()->add($path, "{$label} must be Yes, No or N/A.");
                }
                break;

            case 'measurement':
                if (! is_array($value) || ! array_key_exists('v', $value)) {
                    $validator->errors()->add($path, "{$label} must be sent as a value and unit.");
                    break;
                }

                if ($value['v'] !== null && $value['v'] !== '' && ! is_numeric($value['v'])) {
                    $validator->errors()->add($path, "{$label} must be a number.");
                }

                if (isset($value['u']) && ! in_array($value['u'], ['m²', 'ft²', 'm', 'ft'], true)) {
                    $validator->errors()->add($path, "{$label} has an unsupported unit.");
                }
                break;

            case 'select':
                $allowed = $options[$definition['optionListKey']] ?? [];

                if ($allowed !== [] && ! in_array($value, $allowed, true)) {
                    $validator->errors()->add($path, "{$label} must be one of the configured options.");
                }
                break;

            case 'custom-select':
                $allowed = $definition['optionList'] ?? [];

                if ($allowed !== [] && ! in_array($value, $allowed, true)) {
                    $validator->errors()->add($path, "{$label} must be one of the configured options.");
                }
                break;

            case 'notes':
                if (mb_strlen((string) $value) > 5000) {
                    $validator->errors()->add($path, "{$label} is limited to 5000 characters.");
                }
                break;

            default: // text
                if (mb_strlen((string) $value) > 255) {
                    $validator->errors()->add($path, "{$label} is limited to 255 characters.");
                }
        }
    }
}
