class CalibracaoModel {
  final String id;
  final String equipamentoId;
  final String tipo;
  final String resultado;
  final String responsavel;
  final String realizadaEm;
  final String proximaEm;
  final String observacao;

  const CalibracaoModel({
    this.id = '',
    this.equipamentoId = '',
    this.tipo = '',
    this.resultado = '',
    this.responsavel = '',
    this.realizadaEm = '',
    this.proximaEm = '',
    this.observacao = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'equipamentoId': equipamentoId,
        'tipo': tipo,
        'resultado': resultado,
        'responsavel': responsavel,
        'realizadaEm': realizadaEm,
        'proximaEm': proximaEm,
        'observacao': observacao,
      };

  factory CalibracaoModel.fromMap(Map<String, dynamic> map) => CalibracaoModel(
        id: (map['id'] ?? '').toString(),
        equipamentoId: (map['equipamentoId'] ?? '').toString(),
        tipo: (map['tipo'] ?? '').toString(),
        resultado: (map['resultado'] ?? '').toString(),
        responsavel: (map['responsavel'] ?? '').toString(),
        realizadaEm: (map['realizadaEm'] ?? '').toString(),
        proximaEm: (map['proximaEm'] ?? '').toString(),
        observacao: (map['observacao'] ?? '').toString(),
      );
}
