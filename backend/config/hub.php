<?php

return [
    /*
     | Documents are uploaded to this disk. Keep it private — floor plans and
     | fire risk assessments must not sit behind a guessable public URL.
     */
    'documents_disk' => env('DOCUMENTS_DISK', 'local'),

    'max_document_upload_kb' => (int) env('MAX_DOCUMENT_UPLOAD_KB', 20480),

    'allowed_document_mimes' => [
        'pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp',
        'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt',
        'dwg', 'dxf',
    ],

    /*
     | Accommodation counts that move by at least this many units AND by at
     | least this proportion of their previous value raise a change flag.
     */
    'large_change_min_units' => 10,
    'large_change_min_ratio' => 0.5,

    /*
     | Properties are expected to be re-verified on this cadence. Anything past
     | due is reported as Overdue on the dashboard.
     */
    'verification_interval_days' => 180,
];
