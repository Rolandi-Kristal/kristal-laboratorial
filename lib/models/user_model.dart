class UserModel {
  final String id;
  final String login;
  final String nome;
  final String perfil;
  final String senhaHash;
  final String ativo;
  final String criadoEm;

  const UserModel({
    this.id = '',
    this.login = '',
    this.nome = '',
    this.perfil = '',
    this.senhaHash = '',
    this.ativo = '',
    this.criadoEm = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'login': login,
        'nome': nome,
        'perfil': perfil,
        'senhaHash': senhaHash,
        'ativo': ativo,
        'criadoEm': criadoEm,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: (map['id'] ?? '').toString(),
        login: (map['login'] ?? '').toString(),
        nome: (map['nome'] ?? '').toString(),
        perfil: (map['perfil'] ?? '').toString(),
        senhaHash: (map['senhaHash'] ?? '').toString(),
        ativo: (map['ativo'] ?? '').toString(),
        criadoEm: (map['criadoEm'] ?? '').toString(),
      );
}
