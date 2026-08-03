import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/app_constants.dart';
import 'laudo_hash_service.dart';

class PdfLaudoService {
  PdfLaudoService._();

  static final PdfLaudoService instance = PdfLaudoService._();

  Future<void> gerarLaudoPdf(Map<String, dynamic> laudo) async {
    final pw.Document doc = pw.Document();
    final String hash = LaudoHashService.gerarHash(laudo);
    final String codigo = LaudoHashService.gerarCodigoValidacao(laudo);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Divider(),
              pw.Text(
                AppConstants.developerCredit,
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Código de validação: $codigo',
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
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'KRISTAL LABORATORIAL',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'LAUDO DE EXAME LABORATORIAL',
                style: const pw.TextStyle(fontSize: 13),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text('IDENTIFICAÇÃO DO LAUDO',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('ID do laudo: ${laudo['id'] ?? ''}'),
                  pw.Text('Paciente ID: ${laudo['pacienteId'] ?? ''}'),
                  pw.Text('Pedido ID: ${laudo['pedidoId'] ?? ''}'),
                  pw.Text('Status: ${laudo['status'] ?? ''}'),
                  pw.Text('Criado em: ${laudo['criadoEm'] ?? ''}'),
                  pw.Text('Liberado em: ${laudo['liberadoEm'] ?? ''}'),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'RESULTADOS',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: <String>[
                'Campo',
                'Informação',
              ],
              data: laudo.entries
                  .where((MapEntry<String, dynamic> e) =>
                      e.key != 'id' &&
                      e.key != 'pacienteId' &&
                      e.key != 'pedidoId')
                  .map((MapEntry<String, dynamic> e) =>
                      <String>[e.key, e.value?.toString() ?? ''])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text('VALIDAÇÃO',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Hash SHA-256: $hash'),
                  pw.Text('Código curto: $codigo'),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Este documento deve ser validado pelo responsável técnico antes de uso clínico.',
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
