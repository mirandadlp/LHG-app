<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BootstrapController;
use App\Http\Controllers\Api\ChangeFlagController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\DocumentController;
use App\Http\Controllers\Api\ElevatorController;
use App\Http\Controllers\Api\FieldDefinitionController;
use App\Http\Controllers\Api\ImportController;
use App\Http\Controllers\Api\OptionListController;
use App\Http\Controllers\Api\PropertyController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\StaircaseController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API routes
|--------------------------------------------------------------------------
|
| Everything the iOS app talks to. Authentication is a Sanctum bearer token;
| role checks are the `role:` middleware for coarse gates and PropertyPolicy
| for anything that depends on which property is being touched.
|
*/

Route::post('/auth/login', [AuthController::class, 'login'])
    ->middleware('throttle:10,1')
    ->name('auth.login');

Route::middleware('auth:sanctum')->group(function () {

    /* ---------------------------- Session ---------------------------- */
    Route::post('/auth/logout', [AuthController::class, 'logout'])->name('auth.logout');
    Route::get('/auth/me', [AuthController::class, 'me'])->name('auth.me');
    Route::put('/auth/password', [AuthController::class, 'updatePassword'])->name('auth.password');

    /* --------------------------- Cold start -------------------------- */
    Route::get('/bootstrap', BootstrapController::class)->name('bootstrap');
    Route::get('/dashboard', DashboardController::class)->name('dashboard');

    /* --------------------------- Properties -------------------------- */
    Route::get('/properties', [PropertyController::class, 'index'])->name('properties.index');
    Route::post('/properties', [PropertyController::class, 'store'])->name('properties.store');
    Route::get('/properties/{property}', [PropertyController::class, 'show'])->name('properties.show');
    Route::patch('/properties/{property}', [PropertyController::class, 'update'])->name('properties.update');
    Route::delete('/properties/{property}', [PropertyController::class, 'destroy'])->name('properties.destroy');

    Route::patch('/properties/{property}/accommodation', [PropertyController::class, 'updateAccommodation'])
        ->name('properties.accommodation');

    /* ----------------------- Verification workflow ------------------- */
    Route::post('/properties/{property}/submit', [PropertyController::class, 'submit'])
        ->name('properties.submit');
    Route::post('/properties/{property}/approve', [PropertyController::class, 'approve'])
        ->name('properties.approve');
    Route::post('/properties/{property}/request-changes', [PropertyController::class, 'requestChanges'])
        ->name('properties.requestChanges');
    Route::post('/properties/{property}/request-verification', [PropertyController::class, 'requestVerification'])
        ->name('properties.requestVerification');

    /* ----------------------- Lifts and staircases -------------------- */
    Route::post('/properties/{property}/elevators', [ElevatorController::class, 'store'])
        ->name('elevators.store');
    Route::patch('/properties/{property}/elevators/{elevator}', [ElevatorController::class, 'update'])
        ->name('elevators.update');
    Route::delete('/properties/{property}/elevators/{elevator}', [ElevatorController::class, 'destroy'])
        ->name('elevators.destroy');

    Route::post('/properties/{property}/staircases', [StaircaseController::class, 'store'])
        ->name('staircases.store');
    Route::patch('/properties/{property}/staircases/{staircase}', [StaircaseController::class, 'update'])
        ->name('staircases.update');
    Route::delete('/properties/{property}/staircases/{staircase}', [StaircaseController::class, 'destroy'])
        ->name('staircases.destroy');

    /* ---------------------------- Documents -------------------------- */
    Route::post('/properties/{property}/documents', [DocumentController::class, 'store'])
        ->name('documents.store');
    Route::delete('/properties/{property}/documents/{document}', [DocumentController::class, 'destroy'])
        ->name('documents.destroy');
    Route::get('/documents/{document}/download', [DocumentController::class, 'download'])
        ->name('documents.download');

    /* -------------------------- Change flags ------------------------- */
    Route::post('/properties/{property}/flags/{flag}/resolve', [ChangeFlagController::class, 'resolve'])
        ->name('flags.resolve');

    /* ---------------------------- Reports ---------------------------- */
    Route::get('/reports', [ReportController::class, 'index'])->name('reports.index');
    Route::get('/reports/export/{format}', [ReportController::class, 'export'])->name('reports.export');

    /* ------------------- Corporate administrator only ---------------- */
    Route::middleware('role:admin')->group(function () {
        Route::get('/import/sample', [ImportController::class, 'sample'])->name('import.sample');
        Route::post('/import/preview', [ImportController::class, 'preview'])->name('import.preview');
        Route::post('/import/remap', [ImportController::class, 'remap'])->name('import.remap');
        Route::post('/import/commit', [ImportController::class, 'commit'])->name('import.commit');

        Route::get('/field-definitions', [FieldDefinitionController::class, 'index'])
            ->name('fields.index');
        Route::post('/field-definitions', [FieldDefinitionController::class, 'store'])
            ->name('fields.store');
        Route::delete('/field-definitions/{fieldDefinition}', [FieldDefinitionController::class, 'destroy'])
            ->name('fields.destroy');

        Route::get('/option-lists', [OptionListController::class, 'index'])->name('options.index');
        Route::post('/option-lists/{listKey}', [OptionListController::class, 'store'])->name('options.store');
        Route::delete('/option-lists/{listKey}/{value}', [OptionListController::class, 'destroy'])
            ->name('options.destroy');
    });
});
