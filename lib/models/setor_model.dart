class SetorModel {
  final String id;
  final String nome;
  final String descricao;
  final String ativo;

  const SetorModel({
    this.id = '',
    this.nome = '',
    this.descricao = '',
    this.ativo = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'descricao': descricao,
        'ativo': ativo,
      };

  factory SetorModel.fromMap(Map<String, dynamic> map) => SetorModel(
        id: (map['id'] ?? '').toString(),
        nome: (map['nome'] ?? '').toString(),
        descricao: (map['descricao'] ?? '').toString(),
        ativo: (map['ativo'] ?? '').toString(),
      );
}
