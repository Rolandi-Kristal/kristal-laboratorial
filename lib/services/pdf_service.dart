import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/app_constants.dart';
import 'laudo_hash_service.dart';

class PdfService {
  Future<void> imprimirLaudo({required Map<String,dynamic> paciente, required List<Map<String,dynamic>> resultados}) async {
    final hash = LaudoHashService.gerarHash({'paciente':paciente,'resultados':resultados,'emissao':DateTime.now().toIso8601String()});
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (_) => [
      pw.Text(AppConstants.appName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Text(AppConstants.appSubtitle),
      pw.Divider(),
      pw.Text('Paciente: ${paciente['nome'] ?? ''}'),
      pw.Text('CPF: ${paciente['cpf'] ?? ''}   PRECCP: ${paciente['preccp'] ?? ''}'),
      pw.SizedBox(height: 16),
      pw.Table.fromTextArray(headers: ['Exame','Resultado','Unidade','Referência','Crítico'], data: resultados.map((r)=>[r['exame']??r['exameId']??'', r['valor']??'', r['unidade']??'', r['referencia']??'', r['critico']??'']).toList()),
      pw.SizedBox(height: 20),
      pw.Text('Hash de validação: $hash', style: const pw.TextStyle(fontSize: 8)),
      pw.Text(AppConstants.developerCredit, style: const pw.TextStyle(fontSize: 9)),
    ]));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
