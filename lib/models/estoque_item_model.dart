class EstoqueItemModel {
  final String id;
  final String nome;
  final String categoria;
  final String lote;
  final String validade;
  final String quantidade;
  final String minimo;
  final String unidade;
  final String fornecedor;

  const EstoqueItemModel({
    this.id = '',
    this.nome = '',
    this.categoria = '',
    this.lote = '',
    this.validade = '',
    this.quantidade = '',
    this.minimo = '',
    this.unidade = '',
    this.fornecedor = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'categoria': categoria,
    'lote': lote,
    'validade': validade,
    'quantidade': quantidade,
    'minimo': minimo,
    'unidade': unidade,
    'fornecedor': fornecedor,
  };

  factory EstoqueItemModel.fromMap(Map<String, dynamic> map) => EstoqueItemModel(
    id: (map['id'] ?? '').toString(),
    nome: (map['nome'] ?? '').toString(),
    categoria: (map['categoria'] ?? '').toString(),
    lote: (map['lote'] ?? '').toString(),
    validade: (map['validade'] ?? '').toString(),
    quantidade: (map['quantidade'] ?? '').toString(),
    minimo: (map['minimo'] ?? '').toString(),
    unidade: (map['unidade'] ?? '').toString(),
    fornecedor: (map['fornecedor'] ?? '').toString(),
  );
}
