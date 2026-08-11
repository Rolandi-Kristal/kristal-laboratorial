import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/services/pdf_laudo_service.dart';

void main() {
  test('gera PDF real para laudo identificado', () async {
    final bytes = await PdfLaudoService.instance.gerarBytes(<String, dynamic>{
      'id': 'LAUDO-TESTE-1',
      'pacienteId': 'PAC-1',
      'pedidoId': 'PED-1',
      'status': 'LIBERADO',
      'valor': '98.4',
      'unidade': 'mg/dL',
      'profissionalResponsavel': 'Responsável Técnico',
    });

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('rejeita ID vazio ao salvar PDF', () async {
    expect(
      () => PdfLaudoService.instance.salvarLaudoPdf(<String, dynamic>{}),
      throwsArgumentError,
    );
  });
}
