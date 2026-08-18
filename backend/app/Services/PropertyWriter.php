<?php

namespace App\Services;

use App\Models\ChangeFlag;
use App\Models\ChangeLog;
use App\Models\FieldDefinition;
use App\Models\Property;
use App\Models\PropertyFieldValue;
use App\Models\User;
use App\Support\AccommodationRegistry;
use App\Support\FieldRegistry;
use Illuminate\Support\Facades\DB;

/**
 * Every write to a property record goes through here.
 *
 * Two rules hold for all of it: a change that does not actually change the
 * stored value writes nothing, and a change that does is always accompanied by
 * an audit row saying who made it and why.
 */
class PropertyWriter
{
    /**
     * Apply a bag of field values keyed by field key (siteName, floors, …).
     *
     * @param  array<string, mixed>  $values
     * @return array<int, ChangeLog> the audit rows written
     */
    public function applyValues(Property $property, array $values, User $actor, ?string $reason = null): array
    {
        $definitions = FieldDefinition::activeByKey();
        $before = $property->fieldValueBag();
        $logs = [];

        DB::transaction(function () use ($property, $values, $actor, $reason, $definitions, $before, &$logs) {
            foreach ($values as $key => $value) {
                $definition = $definitions[$key] ?? null;

                if (! $definition) {
                    continue; // Unknown key — ignore rather than guess.
                }

                $previous = $before[$key] ?? null;

                if ($this->display($previous) === $this->display($value)) {
                    continue; // No actual change.
                }

                if (FieldRegistry::field($key)) {
                    $this->writeBaseField($property, $key, $value);
                } else {
                    $this->writeCustomField($property, $key, $value);
                }

                $logs[] = $this->log($property, $definition['label'], $previous, $value, $actor, $reason);
            }

            if ($logs !== []) {
                $this->touchProgress($property);
                $property->save();
            }
        });

        return $logs;
    }

    /**
     * Apply accommodation counts. Returns the flags raised by unusually large
     * movements so the caller can surface them for confirmation.
     *
     * Pass $detectLargeChanges = false when the change is itself the resolution
     * of a flag — reverting 44 back to 28 is a large movement by the numbers,
     * but flagging it would loop forever.
     *
     * @param  array<string, int|null>  $counts
     * @return array{logs: array<int, ChangeLog>, flags: array<int, ChangeFlag>}
     */
    public function applyAccommodation(
        Property $property,
        array $counts,
        User $actor,
        ?string $reason = null,
        bool $detectLargeChanges = true,
    ): array {
        $accommodation = $property->accommodation()->firstOrCreate([]);
        $logs = [];
        $flags = [];

        DB::transaction(function () use ($property, $accommodation, $counts, $actor, $reason, $detectLargeChanges, &$logs, &$flags) {
            foreach ($counts as $key => $value) {
                $column = AccommodationRegistry::column($key);

                if (! $column) {
                    continue;
                }

                $previous = (int) ($accommodation->{$column} ?? 0);
                $next = ($value === null || $value === '') ? null : max(0, (int) $value);

                if ($previous === (int) $next) {
                    continue;
                }

                $accommodation->{$column} = $next;

                $logs[] = $this->log(
                    $property,
                    AccommodationRegistry::label($key),
                    (string) $previous,
                    (string) (int) $next,
                    $actor,
                    $reason,
                );

                if ($detectLargeChanges && AccommodationRegistry::isLargeChange($previous, (int) $next)) {
                    $flags[] = $this->raiseFlag($property, $key, $previous, (int) $next, $actor);
                }
            }

            if ($logs !== []) {
                $accommodation->save();
                $this->touchProgress($property);
                $property->save();
            }
        });

        return ['logs' => $logs, 'flags' => $flags];
    }

    /** Record a structural change (a lift added, a document attached, …). */
    public function logStructural(
        Property $property,
        string $field,
        string $previous,
        string $next,
        User $actor,
        string $reason,
    ): ChangeLog {
        $log = $this->log($property, $field, $previous, $next, $actor, $reason);

        $this->touchProgress($property);
        $property->save();

        return $log;
    }

    /**
     * Record a verification transition. These are corporate decisions, so they
     * are logged as already approved rather than waiting on approval.
     */
    public function logVerification(
        Property $property,
        string $previous,
        string $next,
        User $actor,
        string $reason,
    ): ChangeLog {
        return ChangeLog::create([
            'property_id' => $property->id,
            'field' => 'Verification',
            'previous_value' => $previous,
            'new_value' => $next,
            'changed_by' => $actor->id,
            'changed_by_name' => $actor->name,
            'reason' => $reason,
            'approval_status' => ChangeLog::APPROVED,
            'approved_by' => $actor->id,
            'approved_at' => now(),
        ]);
    }

    /* ------------------------------------------------------------------
     | Internals
     ------------------------------------------------------------------ */

    private function writeBaseField(Property $property, string $key, mixed $value): void
    {
        $field = FieldRegistry::field($key);
        $column = $field['column'];

        if ($field['type'] === 'measurement') {
            $magnitude = is_array($value) ? ($value['v'] ?? null) : null;

            $property->{$column.'_value'} = ($magnitude === null || $magnitude === '') ? null : (float) $magnitude;
            $property->{$column.'_unit'} = is_array($value) ? ($value['u'] ?? 'm²') : null;

            return;
        }

        if ($value === '') {
            $value = null;
        }

        $property->{$column} = match ($field['type']) {
            'number' => $value === null ? null : max(0, (int) $value),
            'decimal' => $value === null ? null : (float) $value,
            default => $value,
        };

        // Keep the manager FK in step with the typed-in manager name so
        // visibility scoping keeps working after a reassignment.
        if ($key === 'managerEmail' && $value) {
            $property->manager_id = User::where('email', $value)->value('id');
        }
    }

    private function writeCustomField(Property $property, string $key, mixed $value): void
    {
        $definition = FieldDefinition::where('key', $key)->where('is_custom', true)->first();

        if (! $definition) {
            return;
        }

        $record = PropertyFieldValue::firstOrNew([
            'property_id' => $property->id,
            'field_definition_id' => $definition->id,
        ]);

        $record->fillTyped($definition->type, $value)->save();

        $property->unsetRelation('fieldValues');
    }

    private function log(
        Property $property,
        string $field,
        mixed $previous,
        mixed $next,
        User $actor,
        ?string $reason,
    ): ChangeLog {
        return ChangeLog::create([
            'property_id' => $property->id,
            'field' => $field,
            'previous_value' => $this->display($previous),
            'new_value' => $this->display($next),
            'changed_by' => $actor->id,
            'changed_by_name' => $actor->name,
            'reason' => $reason ?: $this->defaultReason($actor),
            'approval_status' => ChangeLog::PENDING,
        ]);
    }

    private function raiseFlag(Property $property, string $key, int $previous, int $next, User $actor): ChangeFlag
    {
        // Supersede any open flag on the same field — only the latest matters.
        ChangeFlag::where('property_id', $property->id)
            ->where('accommodation_key', $key)
            ->where('resolution', ChangeFlag::PENDING)
            ->delete();

        return ChangeFlag::create([
            'property_id' => $property->id,
            'accommodation_key' => $key,
            'label' => AccommodationRegistry::label($key),
            'previous_value' => $previous,
            'new_value' => $next,
            'resolution' => ChangeFlag::PENDING,
            'raised_by' => $actor->id,
        ]);
    }

    /** A record being edited for the first time moves off "Not Started". */
    private function touchProgress(Property $property): void
    {
        if ($property->verification_status === Property::STATUS_NOT_STARTED) {
            $property->verification_status = Property::STATUS_IN_PROGRESS;
        }
    }

    private function defaultReason(User $actor): string
    {
        return $actor->isManager()
            ? 'Property manager verification'
            : 'Corporate administrator edit';
    }

    /** Render any value the way the audit trail shows it. */
    private function display(mixed $value): string
    {
        if ($value === null || $value === '') {
            return '—';
        }

        if (is_array($value)) {
            $magnitude = $value['v'] ?? null;

            if ($magnitude === null || $magnitude === '') {
                return '—';
            }

            return rtrim(rtrim(number_format((float) $magnitude, 2, '.', ''), '0'), '.')
                .' '.($value['u'] ?? 'm²');
        }

        if (is_bool($value)) {
            return $value ? 'Yes' : 'No';
        }

        if (is_float($value)) {
            return rtrim(rtrim(number_format($value, 2, '.', ''), '0'), '.');
        }

        return (string) $value;
    }
}
