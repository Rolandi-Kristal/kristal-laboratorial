class ControleQualidadeModel {
  final String id;
  final String setor;
  final String controle;
  final String nivel;
  final String resultado;
  final String esperado;
  final String status;
  final String responsavel;
  final String criadoEm;

  const ControleQualidadeModel({
    this.id = '',
    this.setor = '',
    this.controle = '',
    this.nivel = '',
    this.resultado = '',
    this.esperado = '',
    this.status = '',
    this.responsavel = '',
    this.criadoEm = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'setor': setor,
        'controle': controle,
        'nivel': nivel,
        'resultado': resultado,
        'esperado': esperado,
        'status': status,
        'responsavel': responsavel,
        'criadoEm': criadoEm,
      };

  factory ControleQualidadeModel.fromMap(Map<String, dynamic> map) =>
      ControleQualidadeModel(
        id: (map['id'] ?? '').toString(),
        setor: (map['setor'] ?? '').toString(),
        controle: (map['controle'] ?? '').toString(),
        nivel: (map['nivel'] ?? '').toString(),
        resultado: (map['resultado'] ?? '').toString(),
        esperado: (map['esperado'] ?? '').toString(),
        status: (map['status'] ?? '').toString(),
        responsavel: (map['responsavel'] ?? '').toString(),
        criadoEm: (map['criadoEm'] ?? '').toString(),
      );
}
