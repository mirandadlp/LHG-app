<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Values for custom fields added after launch. Base fields live in real columns
 * on `properties`; anything a corporate administrator adds later lands here, so
 * the business can extend the record without a schema change or an app release.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('property_field_values', function (Blueprint $table) {
            $table->id();
            $table->foreignId('property_id')->constrained()->cascadeOnDelete();
            $table->foreignId('field_definition_id')->constrained()->cascadeOnDelete();

            $table->text('value_text')->nullable();
            $table->decimal('value_number', 16, 4)->nullable();
            $table->date('value_date')->nullable();
            $table->string('value_unit', 16)->nullable();

            $table->timestamps();

            $table->unique(['property_id', 'field_definition_id'], 'property_field_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('property_field_values');
    }
};
