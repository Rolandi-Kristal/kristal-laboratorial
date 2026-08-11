class CsvResultImporter {
  static List<Map<String, String>> parse(String csv) {
    final lines =
        csv.split(RegExp(r'\r?\n')).where((e) => e.trim().isNotEmpty).toList();
    if (lines.length < 2) return [];
    final header = lines.first
        .split(';')
        .map((e) => e.replaceAll('"', '').trim())
        .toList();
    return lines.skip(1).map((l) {
      final c = l.split(';').map((e) => e.replaceAll('"', '').trim()).toList();
      return {
        for (var i = 0; i < header.length; i++)
          header[i]: i < c.length ? c[i] : ''
      };
    }).toList();
  }
}
