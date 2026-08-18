<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Controlled dropdown lists (boroughs, councils, regions, property types,
 * operational statuses, building types, elevator types, document types).
 * Corporate administrators can add and remove entries at runtime.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('option_list_items', function (Blueprint $table) {
            $table->id();
            $table->string('list_key', 64)->index();
            $table->string('value');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->unique(['list_key', 'value']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('option_list_items');
    }
};
