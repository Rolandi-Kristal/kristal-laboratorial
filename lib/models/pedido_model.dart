class PedidoModel {
  final String id;
  final String pacienteId;
  final String medico;
  final String convenio;
  final String prioridade;
  final String status;
  final String observacao;
  final String criadoEm;

  const PedidoModel({
    this.id = '',
    this.pacienteId = '',
    this.medico = '',
    this.convenio = '',
    this.prioridade = '',
    this.status = '',
    this.observacao = '',
    this.criadoEm = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'pacienteId': pacienteId,
        'medico': medico,
        'convenio': convenio,
        'prioridade': prioridade,
        'status': status,
        'observacao': observacao,
        'criadoEm': criadoEm,
      };

  factory PedidoModel.fromMap(Map<String, dynamic> map) => PedidoModel(
        id: (map['id'] ?? '').toString(),
        pacienteId: (map['pacienteId'] ?? '').toString(),
        medico: (map['medico'] ?? '').toString(),
        convenio: (map['convenio'] ?? '').toString(),
        prioridade: (map['prioridade'] ?? '').toString(),
        status: (map['status'] ?? '').toString(),
        observacao: (map['observacao'] ?? '').toString(),
        criadoEm: (map['criadoEm'] ?? '').toString(),
      );
}
