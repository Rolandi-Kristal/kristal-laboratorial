class HematologyDriverProfile {
  const HematologyDriverProfile({
    required this.id,
    required this.nome,
    required this.fabricante,
    required this.modelo,
    required this.setor,
    required this.protocolos,
    required this.conexaoPadrao,
    required this.ativo,
  });

  final String id;
  final String nome;
  final String fabricante;
  final String modelo;
  final String setor;
  final List<String> protocolos;
  final Map<String, Object?> conexaoPadrao;
  final bool ativo;

  factory HematologyDriverProfile.fromJson(Map<String, Object?> json) {
    return HematologyDriverProfile(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      fabricante: json['fabricante']?.toString() ?? '',
      modelo: json['modelo']?.toString() ?? '',
      setor: json['setor']?.toString() ?? 'Hematologia',
      protocolos: (json['protocolos'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      conexaoPadrao: (json['conexaoPadrao'] as Map<dynamic, dynamic>? ??
              <dynamic, dynamic>{})
          .map(
        (dynamic key, dynamic value) => MapEntry<String, Object?>(
          key.toString(),
          value,
        ),
      ),
      ativo: json['ativo']?.toString().toLowerCase() != 'false',
    );
  }
}
