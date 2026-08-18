<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

class PropertyDocument extends Model
{
    protected $guarded = ['id'];

    protected function casts(): array
    {
        return ['size_bytes' => 'integer'];
    }

    public function property(): BelongsTo
    {
        return $this->belongsTo(Property::class);
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    /**
     * A short-lived signed URL. Documents are private — floor plans and fire
     * risk assessments should never sit on a guessable public path.
     */
    public function temporaryUrl(int $minutes = 10): ?string
    {
        $disk = Storage::disk($this->disk);

        if (! $disk->exists($this->path)) {
            return null;
        }

        return route('documents.download', ['document' => $this->id]);
    }

    public function delete(): ?bool
    {
        Storage::disk($this->disk)->delete($this->path);

        return parent::delete();
    }
}
