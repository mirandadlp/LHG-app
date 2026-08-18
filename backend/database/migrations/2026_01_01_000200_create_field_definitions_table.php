<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The field registry. Base fields are seeded and locked (is_custom = false);
 * custom fields are added by corporate administrators and stored as EAV in
 * property_field_values, so new fields appear on every property with no rebuild.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('field_definitions', function (Blueprint $table) {
            $table->id();
            $table->string('key', 64)->unique();
            $table->enum('section', ['general', 'dimensions', 'accessibility', 'building'])->index();
            $table->string('label');

            // text, email, postcode, number, decimal, date, yesno,
            // select, custom-select, measurement, notes
            $table->string('type', 32);

            $table->boolean('required')->default(false);
            $table->string('help')->nullable();
            $table->string('unit', 32)->nullable();

            // For type=select: the option_list_items.list_key to read from.
            $table->string('option_list_key', 64)->nullable();

            // For type=custom-select: an inline list of choices.
            $table->json('option_list')->nullable();

            $table->boolean('is_custom')->default(false)->index();
            $table->unsignedInteger('sort_order')->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('field_definitions');
    }
};
