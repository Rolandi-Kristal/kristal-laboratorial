class ConvenioModel {
  final String id;
  final String nome;
  final String registro;
  final String ativo;

  const ConvenioModel({
    this.id = '',
    this.nome = '',
    this.registro = '',
    this.ativo = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'registro': registro,
    'ativo': ativo,
  };

  factory ConvenioModel.fromMap(Map<String, dynamic> map) => ConvenioModel(
    id: (map['id'] ?? '').toString(),
    nome: (map['nome'] ?? '').toString(),
    registro: (map['registro'] ?? '').toString(),
    ativo: (map['ativo'] ?? '').toString(),
  );
}
