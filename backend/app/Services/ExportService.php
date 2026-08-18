<?php

namespace App\Services;

use Dompdf\Dompdf;
use Dompdf\Options;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

/**
 * Renders report rows into the three formats the business asked for. Exports
 * always contain exactly the columns the user selected, plus the company-total
 * row, so the file matches the screen it was generated from.
 */
class ExportService
{
    public function __construct(private readonly ReportBuilder $reports) {}

    /** @param array<int, array<string, mixed>> $rows */
    public function csv(array $rows, array $columns): string
    {
        $handle = fopen('php://temp', 'r+');

        fputcsv($handle, $columns);

        foreach ($rows as $row) {
            fputcsv($handle, array_map(fn ($column) => $row[$column] ?? '', $columns));
        }

        $totals = $this->reports->totalsRow($rows, $columns);
        fputcsv($handle, array_map(fn ($column) => $totals[$column] ?? '', $columns));

        rewind($handle);
        $csv = stream_get_contents($handle);
        fclose($handle);

        // BOM so Excel opens UTF-8 (m², en-dashes) correctly on Windows.
        return "\xEF\xBB\xBF".$csv;
    }

    /**
     * A two-sheet workbook: the portfolio table, and a summary sheet recording
     * what was exported and whether a filter was applied.
     *
     * @param  array<int, array<string, mixed>>  $rows
     */
    public function xlsx(array $rows, array $columns, array $summary): string
    {
        $spreadsheet = new Spreadsheet;

        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Portfolio');

        $sheet->fromArray($columns, null, 'A1');

        $rowIndex = 2;

        foreach ($rows as $row) {
            $sheet->fromArray(
                array_map(fn ($column) => $row[$column] ?? '', $columns),
                null,
                'A'.$rowIndex++,
            );
        }

        $totals = $this->reports->totalsRow($rows, $columns);
        $sheet->fromArray(
            array_map(fn ($column) => $totals[$column] ?? '', $columns),
            null,
            'A'.$rowIndex,
        );

        $lastColumn = $sheet->getHighestColumn();

        // Navy header band, matching the app.
        $sheet->getStyle("A1:{$lastColumn}1")->applyFromArray([
            'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
            'fill' => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => '1E2749']],
            'alignment' => ['vertical' => Alignment::VERTICAL_CENTER],
        ]);

        $sheet->getStyle("A{$rowIndex}:{$lastColumn}{$rowIndex}")->applyFromArray([
            'font' => ['bold' => true, 'color' => ['rgb' => '8A6A10']],
            'fill' => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => 'FDF3D7']],
        ]);

        foreach (range('A', $lastColumn) as $column) {
            $sheet->getColumnDimension($column)->setAutoSize(true);
        }

        $sheet->freezePane('A2');

        /* -------------------- Summary sheet -------------------- */
        $summarySheet = $spreadsheet->createSheet();
        $summarySheet->setTitle('Summary');
        $summarySheet->fromArray(['Metric', 'Value'], null, 'A1');
        $summarySheet->fromArray(
            array_map(fn ($key, $value) => [$key, $value], array_keys($summary), array_values($summary)),
            null,
            'A2',
        );
        $summarySheet->getStyle('A1:B1')->applyFromArray([
            'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
            'fill' => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => '1E2749']],
        ]);
        $summarySheet->getColumnDimension('A')->setAutoSize(true);
        $summarySheet->getColumnDimension('B')->setAutoSize(true);

        $spreadsheet->setActiveSheetIndex(0);

        $writer = new Xlsx($spreadsheet);

        ob_start();
        $writer->save('php://output');
        $binary = ob_get_clean();

        $spreadsheet->disconnectWorksheets();

        return $binary;
    }

    /** @param array<int, array<string, mixed>> $rows */
    public function pdf(array $rows, array $columns, array $summary): string
    {
        $totals = $this->reports->totalsRow($rows, $columns);

        $html = view('exports.portfolio', [
            'columns' => $columns,
            'rows' => $rows,
            'totals' => $totals,
            'summary' => $summary,
            'generatedAt' => now()->format('j F Y, H:i'),
        ])->render();

        $options = new Options;
        $options->set('isRemoteEnabled', false);
        $options->set('defaultFont', 'DejaVu Sans');

        $dompdf = new Dompdf($options);
        $dompdf->loadHtml($html, 'UTF-8');
        // Landscape: portfolio reports are wide.
        $dompdf->setPaper('a4', 'landscape');
        $dompdf->render();

        return $dompdf->output();
    }
}
