class ReagenteLoteModel {
  final String id;
  final String nome;
  final String fabricante;
  final String lote;
  final String validade;
  final String abertoEm;
  final String quantidade;
  final String status;

  const ReagenteLoteModel({
    this.id = '',
    this.nome = '',
    this.fabricante = '',
    this.lote = '',
    this.validade = '',
    this.abertoEm = '',
    this.quantidade = '',
    this.status = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'fabricante': fabricante,
    'lote': lote,
    'validade': validade,
    'abertoEm': abertoEm,
    'quantidade': quantidade,
    'status': status,
  };

  factory ReagenteLoteModel.fromMap(Map<String, dynamic> map) => ReagenteLoteModel(
    id: (map['id'] ?? '').toString(),
    nome: (map['nome'] ?? '').toString(),
    fabricante: (map['fabricante'] ?? '').toString(),
    lote: (map['lote'] ?? '').toString(),
    validade: (map['validade'] ?? '').toString(),
    abertoEm: (map['abertoEm'] ?? '').toString(),
    quantidade: (map['quantidade'] ?? '').toString(),
    status: (map['status'] ?? '').toString(),
  );
}
