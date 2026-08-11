class PacienteModel {
  final String id;
  final String nome;
  final String cpf;
  final String cns;
  final String preccp;
  final String nascimento;
  final String sexo;
  final String peso;
  final String altura;
  final String telefone;
  final String endereco;
  final String cadebensNumero;
  final String cadebensSituacao;
  final String criadoEm;

  const PacienteModel({
    this.id = '',
    this.nome = '',
    this.cpf = '',
    this.cns = '',
    this.preccp = '',
    this.nascimento = '',
    this.sexo = '',
    this.peso = '',
    this.altura = '',
    this.telefone = '',
    this.endereco = '',
    this.cadebensNumero = '',
    this.cadebensSituacao = '',
    this.criadoEm = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'cpf': cpf,
        'cns': cns,
        'preccp': preccp,
        'nascimento': nascimento,
        'sexo': sexo,
        'peso': peso,
        'altura': altura,
        'telefone': telefone,
        'endereco': endereco,
        'cadebensNumero': cadebensNumero,
        'cadebensSituacao': cadebensSituacao,
        'criadoEm': criadoEm,
      };

  factory PacienteModel.fromMap(Map<String, dynamic> map) => PacienteModel(
        id: (map['id'] ?? '').toString(),
        nome: (map['nome'] ?? '').toString(),
        cpf: (map['cpf'] ?? '').toString(),
        cns: (map['cns'] ?? '').toString(),
        preccp: (map['preccp'] ?? '').toString(),
        nascimento: (map['nascimento'] ?? '').toString(),
        sexo: (map['sexo'] ?? '').toString(),
        peso: (map['peso'] ?? '').toString(),
        altura: (map['altura'] ?? '').toString(),
        telefone: (map['telefone'] ?? '').toString(),
        endereco: (map['endereco'] ?? '').toString(),
        cadebensNumero: (map['cadebensNumero'] ?? '').toString(),
        cadebensSituacao: (map['cadebensSituacao'] ?? '').toString(),
        criadoEm: (map['criadoEm'] ?? '').toString(),
      );
}
