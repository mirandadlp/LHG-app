<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Large-change detection. When an accommodation count moves by 10 or more AND
 * by at least 50% of its previous value, the edit is flagged so the property
 * manager has to confirm it or revert before the record is trusted.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('change_flags', function (Blueprint $table) {
            $table->id();
            $table->foreignId('property_id')->constrained()->cascadeOnDelete();
            $table->string('accommodation_key', 32);
            $table->string('label');
            $table->integer('previous_value');
            $table->integer('new_value');
            $table->enum('resolution', ['Pending', 'Confirmed', 'Reverted'])->default('Pending')->index();
            $table->foreignId('raised_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            // A field can be flagged, resolved, and flagged again later, so the
            // history is not unique per field. "Only one *open* flag per field"
            // is enforced in PropertyWriter::raiseFlag instead.
            $table->index(['property_id', 'accommodation_key'], 'change_flags_property_key_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('change_flags');
    }
};
