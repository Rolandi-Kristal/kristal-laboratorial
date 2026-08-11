class EquipamentoModel {
  final String id;
  final String nome;
  final String fabricante;
  final String modelo;
  final String protocolo;
  final String conexao;
  final String porta;
  final String ip;
  final String ativo;

  const EquipamentoModel({
    this.id = '',
    this.nome = '',
    this.fabricante = '',
    this.modelo = '',
    this.protocolo = '',
    this.conexao = '',
    this.porta = '',
    this.ip = '',
    this.ativo = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'fabricante': fabricante,
        'modelo': modelo,
        'protocolo': protocolo,
        'conexao': conexao,
        'porta': porta,
        'ip': ip,
        'ativo': ativo,
      };

  factory EquipamentoModel.fromMap(Map<String, dynamic> map) =>
      EquipamentoModel(
        id: (map['id'] ?? '').toString(),
        nome: (map['nome'] ?? '').toString(),
        fabricante: (map['fabricante'] ?? '').toString(),
        modelo: (map['modelo'] ?? '').toString(),
        protocolo: (map['protocolo'] ?? '').toString(),
        conexao: (map['conexao'] ?? '').toString(),
        porta: (map['porta'] ?? '').toString(),
        ip: (map['ip'] ?? '').toString(),
        ativo: (map['ativo'] ?? '').toString(),
      );
}
