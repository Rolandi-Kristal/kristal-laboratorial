class ExameItemModel {
  final String id;
  final String exameId;
  final String nome;
  final String unidade;
  final String referencia;
  final String loinc;
  final String ordem;

  const ExameItemModel({
    this.id = '',
    this.exameId = '',
    this.nome = '',
    this.unidade = '',
    this.referencia = '',
    this.loinc = '',
    this.ordem = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'exameId': exameId,
    'nome': nome,
    'unidade': unidade,
    'referencia': referencia,
    'loinc': loinc,
    'ordem': ordem,
  };

  factory ExameItemModel.fromMap(Map<String, dynamic> map) => ExameItemModel(
    id: (map['id'] ?? '').toString(),
    exameId: (map['exameId'] ?? '').toString(),
    nome: (map['nome'] ?? '').toString(),
    unidade: (map['unidade'] ?? '').toString(),
    referencia: (map['referencia'] ?? '').toString(),
    loinc: (map['loinc'] ?? '').toString(),
    ordem: (map['ordem'] ?? '').toString(),
  );
}
