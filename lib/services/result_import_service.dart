import 'audit_service.dart';
import 'equipment_adapter_service.dart';
import 'resultados_service.dart';

class ResultImportService {
  ResultImportService._();

  static final ResultImportService instance = ResultImportService._();

  Future<Map<String, dynamic>> importarMensagem({
    required String protocolo,
    required String mensagem,
    String usuario = 'SISTEMA',
  }) async {
    final Map<String, String> parsed = protocolo.toUpperCase() == 'HL7'
        ? EquipmentAdapterService.instance.parseHl7Oru(mensagem)
        : EquipmentAdapterService.instance.parseAstmResult(mensagem);

    final Map<String, dynamic> resultado = <String, dynamic>{
      'id': 'RESULTADO-${DateTime.now().microsecondsSinceEpoch}',
      'pacienteId': parsed['pacienteId'] ?? '',
      'pedidoId': parsed['pedidoId'] ?? '',
      'amostraId': parsed['amostraId'] ?? '',
      'exameId': parsed['codigo'] ?? parsed['exame'] ?? '',
      'valor': parsed['valor'] ?? '',
      'valorBrutoEquipamento': parsed['valor'] ?? '',
      'mensagemBrutaEquipamento': mensagem,
      'unidade': parsed['unidade'] ?? '',
      'referencia': parsed['referencia'] ?? '',
      'status': 'IMPORTADO',
      'criadoEm': DateTime.now().toIso8601String(),
      'observacao':
          'Importado via $protocolo sem alteração do valor recebido do equipamento.',
    };

    await ResultadosService.instance.salvarResultado(
      resultado: resultado,
      usuario: usuario,
    );

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'IMPORTAR_RESULTADO',
      tabela: 'resultados',
      registroId: resultado['id'].toString(),
      detalhes: 'Resultado importado via protocolo $protocolo.',
    );

    return resultado;
  }
}
