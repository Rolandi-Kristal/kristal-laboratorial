class MedicoSolicitanteModel {
  final String id;
  final String nome;
  final String conselho;
  final String uf;
  final String telefone;
  final String email;

  const MedicoSolicitanteModel({
    this.id = '',
    this.nome = '',
    this.conselho = '',
    this.uf = '',
    this.telefone = '',
    this.email = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'conselho': conselho,
    'uf': uf,
    'telefone': telefone,
    'email': email,
  };

  factory MedicoSolicitanteModel.fromMap(Map<String, dynamic> map) => MedicoSolicitanteModel(
    id: (map['id'] ?? '').toString(),
    nome: (map['nome'] ?? '').toString(),
    conselho: (map['conselho'] ?? '').toString(),
    uf: (map['uf'] ?? '').toString(),
    telefone: (map['telefone'] ?? '').toString(),
    email: (map['email'] ?? '').toString(),
  );
}
