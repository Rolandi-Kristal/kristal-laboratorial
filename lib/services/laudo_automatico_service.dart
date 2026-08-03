import 'config_service.dart';
import 'lab_repository.dart';
import 'laudo_hash_service.dart';

class LaudoAutomaticoService {
  LaudoAutomaticoService._();

  static final LaudoAutomaticoService instance = LaudoAutomaticoService._();

  final LabRepository _repo = LabRepository();

  Future<int> laudarTodosRegistrados() async {
    final String profissional = await ConfigService.instance.getValue(
      'responsavel_tecnico',
      defaultValue: 'Responsavel tecnico nao informado',
    );
    final String conselho = await ConfigService.instance.getValue(
      'responsavel_conselho',
      defaultValue: '',
    );

    final List<Map<String, dynamic>> resultados =
        await _repo.all('resultados', orderBy: 'criadoEm ASC');
    final List<Map<String, dynamic>> laudos = await _repo.all('laudos');
    final Set<String> resultadosLaudados = laudos
        .map((Map<String, dynamic> row) => row['resultadoId']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    int criados = 0;
    for (final Map<String, dynamic> resultado in resultados) {
      final String resultadoId = resultado['id']?.toString() ?? '';
      if (resultadoId.isEmpty || resultadosLaudados.contains(resultadoId)) {
        continue;
      }

      final String now = DateTime.now().toIso8601String();
      final Map<String, dynamic> laudo = <String, dynamic>{
        'id': 'LAUDO-${DateTime.now().microsecondsSinceEpoch}',
        'pacienteId': resultado['pacienteId']?.toString() ?? '',
        'pedidoId': resultado['pedidoId']?.toString() ?? '',
        'resultadoId': resultadoId,
        'exameId': resultado['exameId']?.toString() ?? '',
        'hash': '',
        'status': 'LAUDADO',
        'arquivoPath': '',
        'criadoEm': now,
        'liberadoEm': resultado['liberadoEm']?.toString() ?? '',
        'profissionalResponsavel': profissional,
        'responsavelConselho': conselho,
        'conteudo':
            'Resultado ${resultado['valor'] ?? ''} ${resultado['unidade'] ?? ''}. Referencia: ${resultado['referencia'] ?? ''}.',
        'observacao': resultado['observacao']?.toString() ?? '',
      };
      laudo['hash'] = LaudoHashService.gerarHash(laudo);
      await _repo.upsert('laudos', laudo);
      criados++;
    }

    return criados;
  }
}
