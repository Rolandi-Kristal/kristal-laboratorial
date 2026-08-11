class WorklistModel {
  final String id;
  final String pedidoId;
  final String amostraCodigo;
  final String equipamentoId;
  final String exames;
  final String status;
  final String enviadoEm;
  final String protocolo;

  const WorklistModel({
    this.id = '',
    this.pedidoId = '',
    this.amostraCodigo = '',
    this.equipamentoId = '',
    this.exames = '',
    this.status = '',
    this.enviadoEm = '',
    this.protocolo = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'pedidoId': pedidoId,
        'amostraCodigo': amostraCodigo,
        'equipamentoId': equipamentoId,
        'exames': exames,
        'status': status,
        'enviadoEm': enviadoEm,
        'protocolo': protocolo,
      };

  factory WorklistModel.fromMap(Map<String, dynamic> map) => WorklistModel(
        id: (map['id'] ?? '').toString(),
        pedidoId: (map['pedidoId'] ?? '').toString(),
        amostraCodigo: (map['amostraCodigo'] ?? '').toString(),
        equipamentoId: (map['equipamentoId'] ?? '').toString(),
        exames: (map['exames'] ?? '').toString(),
        status: (map['status'] ?? '').toString(),
        enviadoEm: (map['enviadoEm'] ?? '').toString(),
        protocolo: (map['protocolo'] ?? '').toString(),
      );
}
