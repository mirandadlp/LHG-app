<?php

namespace App\Http\Requests;

/**
 * Creating a property reuses every rule from the update path and adds the one
 * thing a new record cannot go without: a site name.
 */
class StorePropertyRequest extends UpdatePropertyRequest
{
    public function rules(): array
    {
        return [
            ...parent::rules(),
            'values.siteName' => ['required', 'string', 'max:255'],
        ];
    }
}
