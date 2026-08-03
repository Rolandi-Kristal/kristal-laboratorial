import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/app_constants.dart';

class ReportPdfService {
  ReportPdfService._();

  static final ReportPdfService instance = ReportPdfService._();

  Future<void> imprimirTabela({
    required String titulo,
    required List<Map<String, dynamic>> rows,
  }) async {
    final pw.Document doc = pw.Document();

    final List<String> headers =
        rows.isEmpty ? <String>['Informação'] : rows.first.keys.toList();

    final List<List<String>> data = rows.isEmpty
        ? <List<String>>[
            <String>['Nenhum registro encontrado.']
          ]
        : rows.map((Map<String, dynamic> row) {
            return headers
                .map((String h) => row[h]?.toString() ?? '')
                .toList(growable: false);
          }).toList(growable: false);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        footer: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Divider(),
              pw.Text(
                AppConstants.developerCredit,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Center(
              child: pw.Text(
                AppConstants.institutionName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                titulo,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
