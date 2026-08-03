class AuditModel {
  final String id;
  final String usuario;
  final String acao;
  final String tabela;
  final String registroId;
  final String detalhes;
  final String criadoEm;

  const AuditModel({
    this.id = '',
    this.usuario = '',
    this.acao = '',
    this.tabela = '',
    this.registroId = '',
    this.detalhes = '',
    this.criadoEm = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'usuario': usuario,
    'acao': acao,
    'tabela': tabela,
    'registroId': registroId,
    'detalhes': detalhes,
    'criadoEm': criadoEm,
  };

  factory AuditModel.fromMap(Map<String, dynamic> map) => AuditModel(
    id: (map['id'] ?? '').toString(),
    usuario: (map['usuario'] ?? '').toString(),
    acao: (map['acao'] ?? '').toString(),
    tabela: (map['tabela'] ?? '').toString(),
    registroId: (map['registroId'] ?? '').toString(),
    detalhes: (map['detalhes'] ?? '').toString(),
    criadoEm: (map['criadoEm'] ?? '').toString(),
  );
}
