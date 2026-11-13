import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/planner_report.dart';

/// Fonts are bundled with the application; report generation never uses HTTP.
final class PlannerPdf {
  const PlannerPdf();
  Future<Uint8List> build(PlannerReport report) async {
    final regular = await rootBundle.load('assets/fonts/FiraSans-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/FiraSans-SemiBold.ttf');
    return Isolate.run(() => renderPlannerPdf(report, regular, bold));
  }
}

Future<Uint8List> renderPlannerPdf(
  PlannerReport report,
  ByteData regular,
  ByteData bold,
) async {
  final document = pw.Document(
    title: report.title,
    author: 'Deco Planner',
    creator: 'Deco Planner',
  );
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(regular),
    bold: pw.Font.ttf(bold),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 2000,
      theme: theme,
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Deco Planner', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
      build: (_) => [
        pw.Text(
          report.title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Снимок актуальных результатов на момент формирования',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 8),
        for (final line in report.conditions)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
          ),
        for (final table in report.tables) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
            child: pw.Text(
              table.title,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (table.rows.isEmpty)
            pw.Text('Нет', style: const pw.TextStyle(fontSize: 9))
          else
            pw.TableHelper.fromTextArray(
              headers: table.columns,
              data: table.rows,
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.all(5),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .4),
            ),
        ],
      ],
    ),
  );
  return document.save();
}
