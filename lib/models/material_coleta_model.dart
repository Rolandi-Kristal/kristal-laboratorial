class MaterialColetaModel {
  final String id;
  final String nome;
  final String recipiente;
  final String conservacao;
  final String ativo;

  const MaterialColetaModel({
    this.id = '',
    this.nome = '',
    this.recipiente = '',
    this.conservacao = '',
    this.ativo = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'recipiente': recipiente,
        'conservacao': conservacao,
        'ativo': ativo,
      };

  factory MaterialColetaModel.fromMap(Map<String, dynamic> map) =>
      MaterialColetaModel(
        id: (map['id'] ?? '').toString(),
        nome: (map['nome'] ?? '').toString(),
        recipiente: (map['recipiente'] ?? '').toString(),
        conservacao: (map['conservacao'] ?? '').toString(),
        ativo: (map['ativo'] ?? '').toString(),
      );
}
