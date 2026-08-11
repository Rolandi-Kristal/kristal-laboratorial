class AstmParser {
  static List<Map<String, String>> parse(String data) {
    final rows = <Map<String, String>>[];
    for (final line in data.split('\r')) {
      final p = line.split('|');
      if (p.isNotEmpty && p.first == 'R') {
        rows.add({
          'codigo': p.length > 2 ? p[2] : '',
          'valor': p.length > 3 ? p[3] : '',
          'unidade': p.length > 4 ? p[4] : '',
          'referencia': p.length > 5 ? p[5] : ''
        });
      }
    }
    return rows;
  }
}
