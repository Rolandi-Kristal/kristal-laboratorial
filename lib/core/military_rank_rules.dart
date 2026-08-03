class MilitaryRankRules {
  MilitaryRankRules._();

  static const List<String> graduacoes = <String>[
    'Recruta',
    'Soldado',
    'Cabo',
    'Sargento',
    'Subtenente',
    'Aspirante',
    'Tenente',
    'Capitão',
    'Major',
    'Tenente-Coronel',
    'Coronel',
    'General',
    'Marechal',
  ];

  static const Set<String> graduacoesSemPosto = <String>{
    'Recruta',
    'Soldado',
    'Cabo',
    'Subtenente',
    'Aspirante',
    'Capitão',
    'Major',
    'Tenente-Coronel',
    'Coronel',
    'Marechal',
  };

  static const Map<String, List<String>> postosPorGraduacao =
      <String, List<String>>{
    'Sargento': <String>['1º', '2º', '3º'],
    'Tenente': <String>['1º', '2º'],
    'General': <String>['Brigada', 'Divisão', 'Exército'],
  };

  static bool exigePosto(String graduacao) =>
      postosPorGraduacao.containsKey(graduacao.trim());

  static List<String> postos(String graduacao) =>
      postosPorGraduacao[graduacao.trim()] ?? const <String>[];

  static String montar({
    required String graduacao,
    String posto = '',
  }) {
    final String cleanGraduacao = graduacao.trim();
    final String cleanPosto = posto.trim();

    if (cleanGraduacao.isEmpty) {
      return '';
    }

    if (!exigePosto(cleanGraduacao)) {
      return cleanGraduacao;
    }

    if (cleanPosto.isEmpty) {
      return cleanGraduacao;
    }

    if (cleanGraduacao == 'General') {
      return 'General de $cleanPosto';
    }

    return '$cleanPosto $cleanGraduacao';
  }

  static MilitaryRankSelection parse(String value) {
    final String clean = value.trim();
    if (clean.isEmpty) {
      return const MilitaryRankSelection(graduacao: '', posto: '');
    }

    for (final MapEntry<String, List<String>> entry
        in postosPorGraduacao.entries) {
      for (final String posto in entry.value) {
        final String composed = montar(graduacao: entry.key, posto: posto);
        if (clean.toLowerCase() == composed.toLowerCase()) {
          return MilitaryRankSelection(graduacao: entry.key, posto: posto);
        }
      }
    }

    for (final String graduacao in graduacoes) {
      if (clean.toLowerCase() == graduacao.toLowerCase()) {
        return MilitaryRankSelection(graduacao: graduacao, posto: '');
      }
    }

    return MilitaryRankSelection(graduacao: clean, posto: '');
  }
}

class MilitaryRankSelection {
  const MilitaryRankSelection({
    required this.graduacao,
    required this.posto,
  });

  final String graduacao;
  final String posto;
}
