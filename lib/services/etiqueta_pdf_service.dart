import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/app_constants.dart';

class EtiquetaPdfService {
  EtiquetaPdfService._();

  static final EtiquetaPdfService instance = EtiquetaPdfService._();

  Future<void> imprimirEtiqueta({
    required String codigo,
    required String pacienteId,
    required String pedidoId,
    required String exameId,
    String material = '',
  }) async {
    final pw.Document doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          220,
          120,
          marginAll: 8,
        ),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black),
            ),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  AppConstants.appName,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  codigo,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: codigo,
                  width: 190,
                  height: 36,
                  drawText: false,
                ),
                pw.SizedBox(height: 4),
                pw.Text('Paciente: $pacienteId',
                    style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Pedido: $pedidoId | Exame: $exameId',
                    style: const pw.TextStyle(fontSize: 7)),
                if (material.isNotEmpty)
                  pw.Text('Material: $material',
                      style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
