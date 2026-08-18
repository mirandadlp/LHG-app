<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>London Hotel Group — Property Portfolio Report</title>
    <style>
        @page { margin: 18mm 12mm; }
        body { font-family: 'DejaVu Sans', sans-serif; color: #1E2749; font-size: 9px; }
        h1 { font-size: 17px; margin: 0 0 2px; }
        .meta { color: #8A8FA8; font-size: 9px; margin: 0 0 12px; }
        .meta strong { color: #1E2749; }
        table { border-collapse: collapse; width: 100%; }
        th {
            background: #1E2749; color: #fff; text-align: left;
            padding: 6px 5px; font-size: 8px; text-transform: uppercase;
            letter-spacing: 0.04em;
        }
        td { border-bottom: 1px solid rgba(30, 39, 73, 0.12); padding: 5px; }
        tr:nth-child(even) td { background: #F7F8FC; }
        tr.totals td { background: #FDF3D7; color: #8A6A10; font-weight: bold; border-bottom: none; }
        .footer { margin-top: 10px; color: #8A8FA8; font-size: 8px; }
    </style>
</head>
<body>
    <h1>London Hotel Group — Property Portfolio Report</h1>
    <p class="meta">
        @foreach ($summary as $label => $value)
            <strong>{{ $label }}:</strong> {{ $value }}@if (! $loop->last) &nbsp;·&nbsp; @endif
        @endforeach
    </p>

    <table>
        <thead>
            <tr>
                @foreach ($columns as $column)
                    <th>{{ $column }}</th>
                @endforeach
            </tr>
        </thead>
        <tbody>
            @foreach ($rows as $row)
                <tr>
                    @foreach ($columns as $column)
                        <td>{{ $row[$column] ?? '' }}</td>
                    @endforeach
                </tr>
            @endforeach
            <tr class="totals">
                @foreach ($columns as $column)
                    <td>{{ $totals[$column] ?? '' }}</td>
                @endforeach
            </tr>
        </tbody>
    </table>

    <p class="footer">Generated {{ $generatedAt }} · Confidential — internal distribution only.</p>
</body>
</html>
