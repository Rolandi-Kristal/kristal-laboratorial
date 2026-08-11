class ResultadoModel {
  final String id;
  final String pedidoId;
  final String exameId;
  final String amostraId;
  final String valor;
  final String unidade;
  final String referencia;
  final String status;
  final String critico;
  final String liberadoPor;
  final String liberadoEm;

  const ResultadoModel({
    this.id = '',
    this.pedidoId = '',
    this.exameId = '',
    this.amostraId = '',
    this.valor = '',
    this.unidade = '',
    this.referencia = '',
    this.status = '',
    this.critico = '',
    this.liberadoPor = '',
    this.liberadoEm = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'pedidoId': pedidoId,
        'exameId': exameId,
        'amostraId': amostraId,
        'valor': valor,
        'unidade': unidade,
        'referencia': referencia,
        'status': status,
        'critico': critico,
        'liberadoPor': liberadoPor,
        'liberadoEm': liberadoEm,
      };

  factory ResultadoModel.fromMap(Map<String, dynamic> map) => ResultadoModel(
        id: (map['id'] ?? '').toString(),
        pedidoId: (map['pedidoId'] ?? '').toString(),
        exameId: (map['exameId'] ?? '').toString(),
        amostraId: (map['amostraId'] ?? '').toString(),
        valor: (map['valor'] ?? '').toString(),
        unidade: (map['unidade'] ?? '').toString(),
        referencia: (map['referencia'] ?? '').toString(),
        status: (map['status'] ?? '').toString(),
        critico: (map['critico'] ?? '').toString(),
        liberadoPor: (map['liberadoPor'] ?? '').toString(),
        liberadoEm: (map['liberadoEm'] ?? '').toString(),
      );
}
