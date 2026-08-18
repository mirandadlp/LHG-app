<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** One row per staircase, including emergency stairs. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('staircases', function (Blueprint $table) {
            $table->id();
            $table->foreignId('property_id')->constrained()->cascadeOnDelete();
            $table->string('name')->nullable();
            $table->string('location')->nullable();
            $table->unsignedInteger('floors_served')->nullable();
            $table->decimal('width', 6, 2)->nullable();
            $table->enum('classification', [
                'Standard', 'Accessible', 'Emergency', 'Accessible & Emergency',
            ])->default('Standard');
            $table->enum('emergency_exit', ['Yes', 'No'])->default('No');
            $table->text('notes')->nullable();
            $table->unsignedInteger('position')->default(0);
            $table->timestamps();

            $table->index(['property_id', 'position']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('staircases');
    }
};
