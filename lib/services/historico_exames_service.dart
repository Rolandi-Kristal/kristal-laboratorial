import '../models/historico_exame_paciente.dart';
import 'audit_service.dart';
import 'auth_service.dart';
import 'lab_repository.dart';

class HistoricoExamesService {
  HistoricoExamesService._();

  static final HistoricoExamesService instance = HistoricoExamesService._();

  final LabRepository _repo = LabRepository();

  static const String table = 'historico_exames_pacientes';

  Future<void> salvarHistorico({
    required AuthSession session,
    required HistoricoExamePaciente historico,
  }) async {
    final String now = DateTime.now().toIso8601String();

    final HistoricoExamePaciente normalized = historico.copyWith(
      arquivado: historico.arquivado.isEmpty ? '1' : historico.arquivado,
      ativoConsultaRecente: historico.ativoConsultaRecente.isEmpty
          ? '0'
          : historico.ativoConsultaRecente,
      atualizadoEm: now,
      criadoEm: historico.criadoEm.isEmpty ? now : historico.criadoEm,
    );

    await _repo.upsert(table, normalized.toMap());

    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'SALVAR_HISTORICO_EXAME_PERMANENTE',
      tabela: table,
      registroId: normalized.id,
      detalhes:
          'Paciente=${normalized.pacienteNome}; exame=${normalized.exameNome}; pedido=${normalized.pedidoId}',
    );
  }

  Future<List<HistoricoExamePaciente>> consultar({
    String query = '',
    bool somenteHistorico = true,
    bool incluirRecentes = false,
    String? pacienteId,
    String? cpf,
    String? preccp,
    String? dataInicioIso,
    String? dataFimIso,
  }) async {
    final List<Map<String, dynamic>> rows = await _repo.all(table);
    final String q = query.trim().toLowerCase();

    final List<HistoricoExamePaciente> result = rows
        .map((Map<String, dynamic> row) => HistoricoExamePaciente.fromMap(row))
        .where((HistoricoExamePaciente item) {
      if (somenteHistorico && !item.isArquivado) return false;
      if (!incluirRecentes && item.isConsultaRecente) return false;

      if (pacienteId != null &&
          pacienteId.trim().isNotEmpty &&
          item.pacienteId != pacienteId.trim()) {
        return false;
      }

      if (cpf != null && cpf.trim().isNotEmpty && item.cpf != cpf.trim()) {
        return false;
      }

      if (preccp != null &&
          preccp.trim().isNotEmpty &&
          item.preccp != preccp.trim()) {
        return false;
      }

      if (dataInicioIso != null &&
          dataInicioIso.trim().isNotEmpty &&
          item.liberadoEm.isNotEmpty &&
          item.liberadoEm.compareTo(dataInicioIso.trim()) < 0) {
        return false;
      }

      if (dataFimIso != null &&
          dataFimIso.trim().isNotEmpty &&
          item.liberadoEm.isNotEmpty &&
          item.liberadoEm.compareTo(dataFimIso.trim()) > 0) {
        return false;
      }

      if (q.isEmpty) return true;

      final String haystack = <String>[
        item.pacienteNome,
        item.cpf,
        item.preccp,
        item.cns,
        item.pedidoId,
        item.amostraId,
        item.exameNome,
        item.valor,
        item.liberadoEm,
        item.equipamento,
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();

    result.sort(
      (HistoricoExamePaciente a, HistoricoExamePaciente b) =>
          b.liberadoEm.compareTo(a.liberadoEm),
    );

    return result;
  }

  Future<int> totalHistorico() async {
    return (await consultar()).length;
  }
}
