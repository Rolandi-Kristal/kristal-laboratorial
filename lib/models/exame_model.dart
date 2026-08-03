class ExameModel {
  final String id;
  final String codigo;
  final String nome;
  final String setor;
  final String material;
  final String metodo;
  final String loinc;
  final String unidade;
  final String valorReferencia;
  final String criticoBaixo;
  final String criticoAlto;
  final String valorCheio;
  final String valorIndenizar20;
  final String codigoCadebens;
  final String ativo;

  const ExameModel({
    this.id = '',
    this.codigo = '',
    this.nome = '',
    this.setor = '',
    this.material = '',
    this.metodo = '',
    this.loinc = '',
    this.unidade = '',
    this.valorReferencia = '',
    this.criticoBaixo = '',
    this.criticoAlto = '',
    this.valorCheio = '',
    this.valorIndenizar20 = '',
    this.codigoCadebens = '',
    this.ativo = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'codigo': codigo,
    'nome': nome,
    'setor': setor,
    'material': material,
    'metodo': metodo,
    'loinc': loinc,
    'unidade': unidade,
    'valorReferencia': valorReferencia,
    'criticoBaixo': criticoBaixo,
    'criticoAlto': criticoAlto,
    'valorCheio': valorCheio,
    'valorIndenizar20': valorIndenizar20,
    'codigoCadebens': codigoCadebens,
    'ativo': ativo,
  };

  factory ExameModel.fromMap(Map<String, dynamic> map) => ExameModel(
    id: (map['id'] ?? '').toString(),
    codigo: (map['codigo'] ?? '').toString(),
    nome: (map['nome'] ?? '').toString(),
    setor: (map['setor'] ?? '').toString(),
    material: (map['material'] ?? '').toString(),
    metodo: (map['metodo'] ?? '').toString(),
    loinc: (map['loinc'] ?? '').toString(),
    unidade: (map['unidade'] ?? '').toString(),
    valorReferencia: (map['valorReferencia'] ?? '').toString(),
    criticoBaixo: (map['criticoBaixo'] ?? '').toString(),
    criticoAlto: (map['criticoAlto'] ?? '').toString(),
    valorCheio: (map['valorCheio'] ?? '').toString(),
    valorIndenizar20: (map['valorIndenizar20'] ?? '').toString(),
    codigoCadebens: (map['codigoCadebens'] ?? '').toString(),
    ativo: (map['ativo'] ?? '').toString(),
  );
}
