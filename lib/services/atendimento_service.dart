import 'audit_service.dart';
import 'lab_repository.dart';

class AtendimentoService {
  AtendimentoService._();

  static final AtendimentoService instance = AtendimentoService._();

  final LabRepository _repo = LabRepository();

  Future<void> salvarAtendimento({
    required Map<String, dynamic> data,
    required String usuario,
  }) async {
    final String now = DateTime.now().toIso8601String();
    final String id = data['id']?.toString().trim().isNotEmpty == true
        ? data['id'].toString().trim()
        : 'ATD-${DateTime.now().microsecondsSinceEpoch}';
    final String pacienteId =
        data['pacienteId']?.toString().trim().isNotEmpty == true
            ? data['pacienteId'].toString().trim()
            : 'PAC-${DateTime.now().microsecondsSinceEpoch}';
    final String agendamentoId = 'AGE-${DateTime.now().microsecondsSinceEpoch}';
    final String pedidoId = id;

    final Map<String, dynamic> atendimento = Map<String, dynamic>.from(data);
    atendimento['id'] = id;
    atendimento['pacienteId'] = pacienteId;
    atendimento['pedidoId'] = pedidoId;
    atendimento['codigoEtiqueta'] = pedidoId;
    atendimento['valorIndenizar20'] = _calcularVintePorCento(
      atendimento['valorCheio']?.toString() ?? '',
    );
    atendimento['criadoEm'] =
        atendimento['criadoEm']?.toString().isNotEmpty == true
            ? atendimento['criadoEm']
            : now;
    atendimento['atualizadoEm'] = now;

    await _repo.upsert('pacientes', <String, dynamic>{
      'id': pacienteId,
      'nome': atendimento['pacienteNome'] ?? '',
      'cpf': atendimento['cpf'] ?? '',
      'cns': '',
      'preccp': '',
      'nascimento': '',
      'sexo': '',
      'peso': atendimento['peso'] ?? '',
      'altura': atendimento['altura'] ?? '',
      'telefone': atendimento['telefone'] ?? '',
      'endereco': atendimento['endereco'] ?? '',
      'cadebensNumero': atendimento['cadebensNumero'] ?? '',
      'cadebensSituacao': atendimento['cadebensSituacao'] ?? '',
      'criadoEm': now,
      'status': atendimento['statusPaciente'] ?? 'ATIVO',
    });

    await _repo.upsert('agendamentos', <String, dynamic>{
      'id': agendamentoId,
      'tipo': atendimento['grupoAgenda'] == 'PRE_AGENDAMENTO'
          ? 'PRE_AGENDAMENTO'
          : 'AGENDAMENTO',
      'pacienteId': pacienteId,
      'pacienteNome': atendimento['pacienteNome'] ?? '',
      'cpf': atendimento['cpf'] ?? '',
      'telefone': atendimento['telefone'] ?? '',
      'exameId': '',
      'exameNome': atendimento['exames'] ?? '',
      'dataHora': atendimento['dataHora'] ?? atendimento['horario'] ?? '',
      'origem': atendimento['procedenciaPaciente'] ?? '',
      'status': atendimento['statusAtendimento'] ?? 'AGENDADO',
      'prioridade': 'NORMAL',
      'cadebensNumero': atendimento['cadebensNumero'] ?? '',
      'cadebensSituacao': atendimento['cadebensSituacao'] ?? '',
      'peso': atendimento['peso'] ?? '',
      'altura': atendimento['altura'] ?? '',
      'observacao': atendimento['observacao'] ?? '',
      'criadoEm': now,
      'atualizadoEm': now,
    });

    await _repo.upsert('pedidos', <String, dynamic>{
      'id': pedidoId,
      'numeroAtendimento': id,
      'codigoEtiqueta': pedidoId,
      'agendamentoId': agendamentoId,
      'pacienteId': pacienteId,
      'medicoSolicitante': atendimento['medicos'] ?? '',
      'prioridade': 'NORMAL',
      'status': 'ABERTO',
      'valorCheio': atendimento['valorCheio'] ?? '',
      'valorIndenizar20': atendimento['valorIndenizar20'] ?? '',
      'cadebensNumero': atendimento['cadebensNumero'] ?? '',
      'criadoEm': now,
      'observacao': atendimento['observacao'] ?? '',
    });

    if ((atendimento['cadebensNumero']?.toString() ?? '').isNotEmpty) {
      await _repo.upsert('cadebens_integracao', <String, dynamic>{
        'id': 'CAD-${DateTime.now().microsecondsSinceEpoch}',
        'pacienteId': pacienteId,
        'pacienteNome': atendimento['pacienteNome'] ?? '',
        'cpf': atendimento['cpf'] ?? '',
        'numeroBeneficio': atendimento['cadebensNumero'] ?? '',
        'matricula': atendimento['matriculaEmpregado'] ?? '',
        'categoria': atendimento['convenio'] ?? '',
        'situacao': atendimento['cadebensSituacao'] ?? '',
        'dataConsulta': now,
        'origem': 'NOVO_ATENDIMENTO',
        'retorno': atendimento['observacao'] ?? '',
        'status': atendimento['cadebensSituacao'] ?? 'PENDENTE',
        'criadoEm': now,
        'atualizadoEm': now,
      });
    }

    await _repo.upsert('atendimentos', atendimento);

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'SALVAR_ATENDIMENTO',
      tabela: 'atendimentos',
      registroId: id,
      detalhes: 'Novo atendimento salvo com paciente, agendamento e pedido.',
    );
  }

  String _calcularVintePorCento(String value) {
    final String normalized = value
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final double? parsed = double.tryParse(normalized);
    if (parsed == null) return '';
    return (parsed * 0.20).toStringAsFixed(2).replaceAll('.', ',');
  }
}
