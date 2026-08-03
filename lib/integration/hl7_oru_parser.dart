class Hl7OruParser {
  static List<Map<String,String>> parse(String message) {
    final out = <Map<String,String>>[];
    for (final line in message.split(RegExp(r'\r?\n|\r'))) {
      final p = line.split('|');
      if (p.isNotEmpty && p.first == 'OBX') {
        out.add({'codigo': p.length>3 ? p[3] : '', 'valor': p.length>5 ? p[5] : '', 'unidade': p.length>6 ? p[6] : '', 'referencia': p.length>7 ? p[7] : '', 'flag': p.length>8 ? p[8] : ''});
      }
    }
    return out;
  }
}
