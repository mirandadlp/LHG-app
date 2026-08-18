<?php

namespace App\Models;

use App\Support\AccommodationRegistry;
use App\Support\FieldRegistry;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class Property extends Model
{
    use HasFactory, SoftDeletes;

    public const STATUS_NOT_STARTED = 'Not Started';

    public const STATUS_IN_PROGRESS = 'In Progress';

    public const STATUS_SUBMITTED = 'Submitted';

    public const STATUS_CHANGES_REQUESTED = 'Changes Requested';

    public const STATUS_VERIFIED = 'Verified';

    public const STATUS_OVERDUE = 'Overdue';

    public const STATUS_NEEDS_REVIEW = 'Needs Review';

    public const STATUSES = [
        self::STATUS_NOT_STARTED,
        self::STATUS_IN_PROGRESS,
        self::STATUS_SUBMITTED,
        self::STATUS_CHANGES_REQUESTED,
        self::STATUS_VERIFIED,
        self::STATUS_OVERDUE,
        self::STATUS_NEEDS_REVIEW,
    ];

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'opened_date' => 'date:Y-m-d',
            'verification_due_on' => 'date:Y-m-d',
            'submitted_at' => 'datetime',
            'verified_at' => 'datetime',
            'single_size_value' => 'float',
            'double_size_value' => 'float',
            'triple_size_value' => 'float',
            'avg_bedroom_value' => 'float',
            'min_bedroom_value' => 'float',
            'max_bedroom_value' => 'float',
            'building_area_value' => 'float',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Property $property) {
            $property->public_id ??= (string) Str::uuid();
        });

        static::created(function (Property $property) {
            $property->accommodation()->firstOrCreate([]);
        });
    }

    /* ------------------------------------------------------------------
     | Relations
     ------------------------------------------------------------------ */

    public function manager(): BelongsTo
    {
        return $this->belongsTo(User::class, 'manager_id');
    }

    public function accommodation(): HasOne
    {
        return $this->hasOne(PropertyAccommodation::class);
    }

    public function elevators(): HasMany
    {
        return $this->hasMany(Elevator::class)->orderBy('position')->orderBy('id');
    }

    public function staircases(): HasMany
    {
        return $this->hasMany(Staircase::class)->orderBy('position')->orderBy('id');
    }

    public function documents(): HasMany
    {
        return $this->hasMany(PropertyDocument::class)->latest('created_at');
    }

    public function changeLogs(): HasMany
    {
        return $this->hasMany(ChangeLog::class)->latest('created_at')->latest('id');
    }

    public function changeFlags(): HasMany
    {
        return $this->hasMany(ChangeFlag::class);
    }

    public function openFlags(): HasMany
    {
        return $this->changeFlags()->where('resolution', ChangeFlag::PENDING);
    }

    public function fieldValues(): HasMany
    {
        return $this->hasMany(PropertyFieldValue::class);
    }

    /* ------------------------------------------------------------------
     | Query scopes
     ------------------------------------------------------------------ */

    /** Property managers only ever see the properties they are named on. */
    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        if ($user->isManager()) {
            return $query->where(function (Builder $q) use ($user) {
                $q->where('manager_id', $user->id)
                    ->orWhere('manager_email', $user->email);
            });
        }

        return $query;
    }

    public function scopeFiltered(Builder $query, array $filters): Builder
    {
        foreach (['borough', 'council', 'region', 'property_type'] as $column) {
            if (! empty($filters[$column])) {
                $query->where($column, $filters[$column]);
            }
        }

        if (! empty($filters['verification'])) {
            $query->where('verification_status', $filters['verification']);
        }

        if (! empty($filters['q'])) {
            $term = '%'.str_replace(['%', '_'], ['\%', '\_'], $filters['q']).'%';

            $query->where(function (Builder $q) use ($term) {
                foreach ([
                    'site_name', 'property_name', 'address_line1', 'address_line2',
                    'city', 'postcode', 'borough', 'council', 'region', 'manager_name',
                ] as $column) {
                    $q->orWhere($column, 'like', $term);
                }
            });
        }

        return $query;
    }

    /* ------------------------------------------------------------------
     | Field values — the artifact-shaped `values` bag
     ------------------------------------------------------------------ */

    /**
     * Read every base and custom field into one dictionary keyed by field key,
     * which is the exact shape the iOS client renders from.
     */
    public function fieldValueBag(): array
    {
        $values = [];

        foreach (FieldRegistry::baseFields() as $field) {
            $values[$field['key']] = $this->readBaseField($field);
        }

        // Every active custom field is present on every property, even before
        // anyone fills it in — a field added this morning reads as empty, not
        // as missing. Seed the keys first, then overlay what is stored.
        foreach (FieldDefinition::activeDefinitions() as $definition) {
            if ($definition['custom']) {
                $values[$definition['key']] = null;
            }
        }

        foreach ($this->fieldValues as $custom) {
            $definition = $custom->fieldDefinition;

            if ($definition && $definition->is_custom) {
                $values[$definition->key] = $custom->typedValue($definition->type);
            }
        }

        return $values;
    }

    private function readBaseField(array $field): mixed
    {
        $column = $field['column'];

        if ($field['type'] === 'measurement') {
            $value = $this->{$column.'_value'};

            if ($value === null) {
                return null;
            }

            return ['v' => (float) $value, 'u' => $this->{$column.'_unit'} ?: 'm²'];
        }

        $value = $this->{$column};

        if ($value === null) {
            return null;
        }

        return match ($field['type']) {
            'number' => (int) $value,
            'decimal' => (float) $value,
            'date' => $value instanceof \DateTimeInterface ? $value->format('Y-m-d') : (string) $value,
            default => $value,
        };
    }

    /** True when the value counts as "filled" for completeness scoring. */
    public static function isFilled(mixed $value): bool
    {
        if ($value === null || $value === '') {
            return false;
        }

        if (is_array($value)) {
            return isset($value['v']) && $value['v'] !== null && $value['v'] !== '';
        }

        return true;
    }

    /* ------------------------------------------------------------------
     | Derived figures
     ------------------------------------------------------------------ */

    public function totalUnits(): int
    {
        return $this->accommodation?->total() ?? 0;
    }

    /**
     * Percentage of the record that is filled in. Mirrors the original scoring:
     * every applicable field counts once, plus three structural checks for
     * accommodation, lifts and stairs.
     */
    public function completeness(?array $definitions = null): int
    {
        $definitions ??= FieldDefinition::activeDefinitions();
        $values = $this->fieldValueBag();

        $applicable = array_filter($definitions, fn ($d) => ($d['type'] ?? null) !== 'file');
        $total = count($applicable) + 3;

        if ($total === 0) {
            return 0;
        }

        $filled = 0;

        foreach ($applicable as $definition) {
            if (self::isFilled($values[$definition['key']] ?? null)) {
                $filled++;
            }
        }

        if ($this->totalUnits() > 0) {
            $filled++;
        }

        if ($this->elevators->isNotEmpty()) {
            $filled++;
        }

        if ($this->staircases->isNotEmpty()) {
            $filled++;
        }

        return (int) round(($filled / $total) * 100);
    }

    /**
     * @return array{required: array<int, array>, optional: array<int, array>}
     */
    public function missingFields(?array $definitions = null): array
    {
        $definitions ??= FieldDefinition::activeDefinitions();
        $values = $this->fieldValueBag();

        $required = [];
        $optional = [];

        foreach ($definitions as $definition) {
            if (($definition['type'] ?? null) === 'file') {
                continue;
            }

            if (self::isFilled($values[$definition['key']] ?? null)) {
                continue;
            }

            $entry = [
                'key' => $definition['key'],
                'label' => $definition['label'],
                'section' => $definition['section'],
            ];

            if (! empty($definition['required'])) {
                $required[] = $entry;
            } else {
                $optional[] = $entry;
            }
        }

        return ['required' => $required, 'optional' => $optional];
    }

    public function flatsTotal(): int
    {
        return $this->accommodation?->sumOf(AccommodationRegistry::FLAT_KEYS) ?? 0;
    }

    public function housesTotal(): int
    {
        return $this->accommodation?->sumOf(AccommodationRegistry::HOUSE_KEYS) ?? 0;
    }

    public function fullAddress(): string
    {
        return collect([$this->address_line1, $this->address_line2, $this->city, $this->postcode])
            ->filter()
            ->join(', ');
    }
}
