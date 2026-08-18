<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Accommodation counts, one row per property. Null means "not recorded" and is
 * treated as zero when totalling, matching the behaviour of the original app.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('property_accommodations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('property_id')->unique()->constrained()->cascadeOnDelete();

            // Rooms
            $table->unsignedInteger('singles')->nullable();
            $table->unsignedInteger('doubles')->nullable();
            $table->unsignedInteger('triples')->nullable();
            $table->unsignedInteger('wc_sc')->nullable();

            // Flats
            $table->unsignedInteger('flat1')->nullable();
            $table->unsignedInteger('flat2')->nullable();
            $table->unsignedInteger('flat3')->nullable();
            $table->unsignedInteger('wc_flats')->nullable();

            // Houses
            $table->unsignedInteger('house2')->nullable();
            $table->unsignedInteger('house3')->nullable();
            $table->unsignedInteger('house4')->nullable();
            $table->unsignedInteger('house5')->nullable();
            $table->unsignedInteger('wc_houses')->nullable();

            // Other
            $table->unsignedInteger('other')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('property_accommodations');
    }
};
