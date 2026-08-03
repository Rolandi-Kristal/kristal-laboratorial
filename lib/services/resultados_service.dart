import 'audit_service.dart';
import 'lab_repository.dart';
import 'result_validation_service.dart';

class ResultadosService {
  ResultadosService._();

  static final ResultadosService instance = ResultadosService._();

  final LabRepository _repo = LabRepository();

  Future<void> salvarResultado({
    required Map<String, dynamic> resultado,
    String usuario = 'SISTEMA',
  }) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(resultado);

    final String valor = data['valor']?.toString() ?? '';
    final String referencia = data['referencia']?.toString() ?? '';

    data['critico'] = ResultValidationService.isCritical(valor, referencia)
        ? 'SIM'
        : (data['critico']?.toString().isEmpty ?? true)
            ? 'NÃO'
            : data['critico'].toString();

    if ((data['status']?.toString() ?? '').isEmpty) {
      data['status'] = 'DIGITADO';
    }

    data['criadoEm'] ??= DateTime.now().toIso8601String();

    await _repo.upsert('resultados', data);

    if (data['critico'] == 'SIM') {
      await AuditService.instance.registrar(
        usuario: usuario,
        acao: 'RESULTADO_CRITICO',
        tabela: 'resultados',
        registroId: data['id']?.toString() ?? '',
        detalhes: 'Resultado crítico detectado automaticamente.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> listarResultados() {
    return _repo.all('resultados', orderBy: 'criadoEm DESC');
  }
}
