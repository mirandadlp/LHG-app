<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** A property can have any number of lifts — one row per lift. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('elevators', function (Blueprint $table) {
            $table->id();
            $table->foreignId('property_id')->constrained()->cascadeOnDelete();
            $table->string('name')->nullable();
            $table->string('type')->default('Passenger');
            $table->unsignedInteger('capacity')->nullable();
            $table->unsignedInteger('max_occupancy')->nullable();
            $table->decimal('width', 6, 2)->nullable();
            $table->decimal('depth', 6, 2)->nullable();
            $table->decimal('height', 6, 2)->nullable();
            $table->decimal('door_width', 6, 2)->nullable();
            $table->enum('accessible', ['Yes', 'No'])->default('Yes');
            $table->enum('service', ['Yes', 'No'])->default('No');
            $table->enum('passenger', ['Yes', 'No'])->default('Yes');
            $table->text('notes')->nullable();
            $table->unsignedInteger('position')->default(0);
            $table->timestamps();

            $table->index(['property_id', 'position']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('elevators');
    }
};
