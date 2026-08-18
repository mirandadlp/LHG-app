<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One row per property. Every base field from the field registry has a real
 * column here so the portfolio stays fast to filter, sort and aggregate.
 * Custom fields added later live in property_field_values.
 *
 * Measurement fields are stored as a value + unit pair (e.g. 12.6 m²).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('properties', function (Blueprint $table) {
            $table->id();
            $table->uuid('public_id')->unique();

            /* ---------------- Verification workflow ---------------- */
            $table->enum('verification_status', [
                'Not Started',
                'In Progress',
                'Submitted',
                'Changes Requested',
                'Verified',
                'Overdue',
                'Needs Review',
            ])->default('Not Started')->index();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->foreignId('verified_by')->nullable()->constrained('users')->nullOnDelete();
            $table->date('verification_due_on')->nullable();

            /* ---------------- General information ---------------- */
            $table->string('site_name')->index();
            $table->string('property_name')->nullable();
            $table->string('address_line1')->nullable();
            $table->string('address_line2')->nullable();
            $table->string('city')->nullable();
            $table->string('postcode', 16)->nullable()->index();
            $table->string('borough')->nullable()->index();
            $table->string('council')->nullable()->index();
            $table->string('region')->nullable()->index();
            $table->string('property_type')->nullable()->index();
            $table->string('ownership_company')->nullable();
            $table->string('management_company')->nullable();

            // The assigned property manager. manager_name is kept alongside the
            // FK so historic records still read correctly if an account is removed.
            $table->foreignId('manager_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('manager_name')->nullable()->index();
            $table->string('manager_email')->nullable();
            $table->string('manager_phone')->nullable();

            $table->string('operational_status')->nullable()->index();
            $table->date('opened_date')->nullable();
            $table->text('general_notes')->nullable();

            /* ---------------- Room dimensions ---------------- */
            foreach ([
                'single_size', 'double_size', 'triple_size',
                'avg_bedroom', 'min_bedroom', 'max_bedroom',
            ] as $measurement) {
                $table->decimal($measurement.'_value', 10, 2)->nullable();
                $table->string($measurement.'_unit', 8)->nullable();
            }
            $table->text('dimension_notes')->nullable();

            /* ---------------- Accessibility ---------------- */
            // Yes / No / N/A tri-state, matching the field registry.
            foreach ([
                'wheelchair_entrance', 'step_free', 'accessible_bedrooms',
                'accessible_bathrooms', 'accessible_elevators', 'accessible_parking',
                'ramp_access', 'handrails', 'hearing_assistance', 'visual_assistance',
            ] as $flag) {
                $table->enum($flag, ['Yes', 'No', 'N/A'])->nullable();
            }
            $table->unsignedInteger('accessible_bedroom_count')->nullable();
            $table->string('other_accessibility')->nullable();
            $table->text('accessibility_notes')->nullable();

            /* ---------------- Building ---------------- */
            $table->unsignedInteger('floors')->nullable();
            $table->decimal('building_area_value', 12, 2)->nullable();
            $table->string('building_area_unit', 8)->nullable();
            $table->unsignedInteger('building_count')->nullable();
            $table->unsignedInteger('entrances')->nullable();
            $table->unsignedInteger('emergency_exits')->nullable();
            $table->unsignedInteger('parking_spaces')->nullable();
            $table->unsignedInteger('accessible_parking_spaces')->nullable();
            $table->text('fire_safety')->nullable();
            $table->string('building_type')->nullable();
            $table->unsignedSmallInteger('construction_year')->nullable();
            $table->unsignedSmallInteger('renovation_year')->nullable();
            $table->text('building_notes')->nullable();

            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('properties');
    }
};
