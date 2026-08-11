class AmostraModel {
  final String id;
  final String pedidoId;
  final String codigo;
  final String material;
  final String status;
  final String coletador;
  final String coletadoEm;
  final String observacao;

  const AmostraModel({
    this.id = '',
    this.pedidoId = '',
    this.codigo = '',
    this.material = '',
    this.status = '',
    this.coletador = '',
    this.coletadoEm = '',
    this.observacao = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'pedidoId': pedidoId,
        'codigo': codigo,
        'material': material,
        'status': status,
        'coletador': coletador,
        'coletadoEm': coletadoEm,
        'observacao': observacao,
      };

  factory AmostraModel.fromMap(Map<String, dynamic> map) => AmostraModel(
        id: (map['id'] ?? '').toString(),
        pedidoId: (map['pedidoId'] ?? '').toString(),
        codigo: (map['codigo'] ?? '').toString(),
        material: (map['material'] ?? '').toString(),
        status: (map['status'] ?? '').toString(),
        coletador: (map['coletador'] ?? '').toString(),
        coletadoEm: (map['coletadoEm'] ?? '').toString(),
        observacao: (map['observacao'] ?? '').toString(),
      );
}
