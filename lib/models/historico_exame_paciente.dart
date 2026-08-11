class HistoricoExamePaciente {
  final String id;
  final String pacienteId;
  final String pacienteNome;
  final String cpf;
  final String preccp;
  final String cns;
  final String pedidoId;
  final String amostraId;
  final String exameId;
  final String exameNome;
  final String resultadoId;
  final String valor;
  final String unidade;
  final String referencia;
  final String statusLaudo;
  final String critico;
  final String coletadoEm;
  final String liberadoEm;
  final String medicoResponsavel;
  final String profissionalResponsavel;
  final String equipamento;
  final String origem;
  final String loteBackup;
  final String tipoRegistro;
  final String ativoConsultaRecente;
  final String arquivado;
  final String criadoEm;
  final String atualizadoEm;
  final String observacao;

  const HistoricoExamePaciente({
    required this.id,
    required this.pacienteId,
    required this.pacienteNome,
    required this.cpf,
    required this.preccp,
    required this.cns,
    required this.pedidoId,
    required this.amostraId,
    required this.exameId,
    required this.exameNome,
    required this.resultadoId,
    required this.valor,
    required this.unidade,
    required this.referencia,
    required this.statusLaudo,
    required this.critico,
    required this.coletadoEm,
    required this.liberadoEm,
    required this.medicoResponsavel,
    required this.profissionalResponsavel,
    required this.equipamento,
    required this.origem,
    required this.loteBackup,
    required this.tipoRegistro,
    required this.ativoConsultaRecente,
    required this.arquivado,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.observacao,
  });

  bool get isArquivado => arquivado == '1';
  bool get isConsultaRecente => ativoConsultaRecente == '1';
  bool get isCritico => critico.toUpperCase() == 'SIM';

  factory HistoricoExamePaciente.fromMap(Map<String, dynamic> map) {
    return HistoricoExamePaciente(
      id: map['id']?.toString() ?? '',
      pacienteId: map['pacienteId']?.toString() ?? '',
      pacienteNome: map['pacienteNome']?.toString() ?? '',
      cpf: map['cpf']?.toString() ?? '',
      preccp: map['preccp']?.toString() ?? '',
      cns: map['cns']?.toString() ?? '',
      pedidoId: map['pedidoId']?.toString() ?? '',
      amostraId: map['amostraId']?.toString() ?? '',
      exameId: map['exameId']?.toString() ?? '',
      exameNome: map['exameNome']?.toString() ?? '',
      resultadoId: map['resultadoId']?.toString() ?? '',
      valor: map['valor']?.toString() ?? '',
      unidade: map['unidade']?.toString() ?? '',
      referencia: map['referencia']?.toString() ?? '',
      statusLaudo: map['statusLaudo']?.toString() ?? '',
      critico: map['critico']?.toString() ?? 'NÃO',
      coletadoEm: map['coletadoEm']?.toString() ?? '',
      liberadoEm: map['liberadoEm']?.toString() ?? '',
      medicoResponsavel: map['medicoResponsavel']?.toString() ?? '',
      profissionalResponsavel: map['profissionalResponsavel']?.toString() ?? '',
      equipamento: map['equipamento']?.toString() ?? '',
      origem: map['origem']?.toString() ?? '',
      loteBackup: map['loteBackup']?.toString() ?? '',
      tipoRegistro: map['tipoRegistro']?.toString() ?? 'HISTORICO_PERMANENTE',
      ativoConsultaRecente: map['ativoConsultaRecente']?.toString() ?? '0',
      arquivado: map['arquivado']?.toString() ?? '1',
      criadoEm: map['criadoEm']?.toString() ?? '',
      atualizadoEm: map['atualizadoEm']?.toString() ?? '',
      observacao: map['observacao']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'pacienteId': pacienteId,
      'pacienteNome': pacienteNome,
      'cpf': cpf,
      'preccp': preccp,
      'cns': cns,
      'pedidoId': pedidoId,
      'amostraId': amostraId,
      'exameId': exameId,
      'exameNome': exameNome,
      'resultadoId': resultadoId,
      'valor': valor,
      'unidade': unidade,
      'referencia': referencia,
      'statusLaudo': statusLaudo,
      'critico': critico,
      'coletadoEm': coletadoEm,
      'liberadoEm': liberadoEm,
      'medicoResponsavel': medicoResponsavel,
      'profissionalResponsavel': profissionalResponsavel,
      'equipamento': equipamento,
      'origem': origem,
      'loteBackup': loteBackup,
      'tipoRegistro': tipoRegistro,
      'ativoConsultaRecente': ativoConsultaRecente,
      'arquivado': arquivado,
      'criadoEm': criadoEm,
      'atualizadoEm': atualizadoEm,
      'observacao': observacao,
    };
  }

  HistoricoExamePaciente copyWith({
    String? id,
    String? pacienteId,
    String? pacienteNome,
    String? cpf,
    String? preccp,
    String? cns,
    String? pedidoId,
    String? amostraId,
    String? exameId,
    String? exameNome,
    String? resultadoId,
    String? valor,
    String? unidade,
    String? referencia,
    String? statusLaudo,
    String? critico,
    String? coletadoEm,
    String? liberadoEm,
    String? medicoResponsavel,
    String? profissionalResponsavel,
    String? equipamento,
    String? origem,
    String? loteBackup,
    String? tipoRegistro,
    String? ativoConsultaRecente,
    String? arquivado,
    String? criadoEm,
    String? atualizadoEm,
    String? observacao,
  }) {
    return HistoricoExamePaciente(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      pacienteNome: pacienteNome ?? this.pacienteNome,
      cpf: cpf ?? this.cpf,
      preccp: preccp ?? this.preccp,
      cns: cns ?? this.cns,
      pedidoId: pedidoId ?? this.pedidoId,
      amostraId: amostraId ?? this.amostraId,
      exameId: exameId ?? this.exameId,
      exameNome: exameNome ?? this.exameNome,
      resultadoId: resultadoId ?? this.resultadoId,
      valor: valor ?? this.valor,
      unidade: unidade ?? this.unidade,
      referencia: referencia ?? this.referencia,
      statusLaudo: statusLaudo ?? this.statusLaudo,
      critico: critico ?? this.critico,
      coletadoEm: coletadoEm ?? this.coletadoEm,
      liberadoEm: liberadoEm ?? this.liberadoEm,
      medicoResponsavel: medicoResponsavel ?? this.medicoResponsavel,
      profissionalResponsavel:
          profissionalResponsavel ?? this.profissionalResponsavel,
      equipamento: equipamento ?? this.equipamento,
      origem: origem ?? this.origem,
      loteBackup: loteBackup ?? this.loteBackup,
      tipoRegistro: tipoRegistro ?? this.tipoRegistro,
      ativoConsultaRecente: ativoConsultaRecente ?? this.ativoConsultaRecente,
      arquivado: arquivado ?? this.arquivado,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      observacao: observacao ?? this.observacao,
    );
  }
}
