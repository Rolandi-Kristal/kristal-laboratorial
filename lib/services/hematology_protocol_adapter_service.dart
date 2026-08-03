import 'dart:convert';

class HematologyProtocolAdapterService {
  HematologyProtocolAdapterService._();

  static final HematologyProtocolAdapterService instance =
      HematologyProtocolAdapterService._();

  Map<String, Object?> parseIncomingMessage(String raw) {
    final String message = raw.trim();

    if (message.isEmpty) {
      return <String, Object?>{'ok': false, 'tipo': 'VAZIO', 'erro': 'Mensagem vazia.'};
    }

    if (message.contains('MSH|') || message.contains('OBX|')) {
      return _parseHl7(message);
    }

    if (message.contains('\x02') ||
        message.contains('\x03') ||
        message.contains('H|\\^&') ||
        message.contains('R|')) {
      return _parseAstm(message);
    }

    if (message.contains(';') || message.contains(',') || message.contains('\t')) {
      return _parseDelimited(message);
    }

    return <String, Object?>{
      'ok': true,
      'tipo': 'TXT',
      'conteudoBruto': message,
      'resultados': <Map<String, Object?>>[],
    };
  }

  Map<String, Object?> _parseHl7(String raw) {
    final List<String> lines = raw.split(RegExp(r'\r?\n|\r'));
    final List<Map<String, Object?>> results = <Map<String, Object?>>[];

    for (final String line in lines) {
      final List<String> fields = line.split('|');

      if (fields.isNotEmpty && fields.first == 'OBX') {
        results.add(<String, Object?>{
          'codigo': fields.length > 3 ? fields[3] : '',
          'valor': fields.length > 5 ? fields[5] : '',
          'unidade': fields.length > 6 ? fields[6] : '',
          'referencia': fields.length > 7 ? fields[7] : '',
          'flag': fields.length > 8 ? fields[8] : '',
        });
      }
    }

    return <String, Object?>{'ok': true, 'tipo': 'HL7', 'resultados': results, 'conteudoBruto': raw};
  }

  Map<String, Object?> _parseAstm(String raw) {
    final String cleaned = raw
        .replaceAll('\x02', '')
        .replaceAll('\x03', '')
        .replaceAll('\x04', '')
        .replaceAll('\x05', '')
        .replaceAll('\x06', '')
        .replaceAll('\x15', '');

    final List<String> lines = cleaned.split(RegExp(r'\r?\n|\r'));
    final List<Map<String, Object?>> results = <Map<String, Object?>>[];

    for (final String line in lines) {
      final List<String> fields = line.split('|');

      if (fields.isNotEmpty && fields.first.startsWith('R')) {
        results.add(<String, Object?>{
          'codigo': fields.length > 2 ? fields[2] : '',
          'valor': fields.length > 3 ? fields[3] : '',
          'unidade': fields.length > 4 ? fields[4] : '',
          'referencia': fields.length > 5 ? fields[5] : '',
          'flag': fields.length > 6 ? fields[6] : '',
        });
      }
    }

    return <String, Object?>{'ok': true, 'tipo': 'ASTM', 'resultados': results, 'conteudoBruto': raw};
  }

  Map<String, Object?> _parseDelimited(String raw) {
    final String separator = raw.contains(';') ? ';' : raw.contains('\t') ? '\t' : ',';
    final List<Map<String, Object?>> results = <Map<String, Object?>>[];

    for (final String line in raw.split(RegExp(r'\r?\n'))) {
      final List<String> fields = line.split(separator);

      if (fields.length >= 2) {
        results.add(<String, Object?>{
          'codigo': fields[0].trim(),
          'valor': fields[1].trim(),
          'unidade': fields.length > 2 ? fields[2].trim() : '',
          'referencia': fields.length > 3 ? fields[3].trim() : '',
          'flag': fields.length > 4 ? fields[4].trim() : '',
        });
      }
    }

    return <String, Object?>{'ok': true, 'tipo': 'DELIMITADO', 'resultados': results, 'conteudoBruto': raw};
  }

  String toJson(Map<String, Object?> message) {
    return const JsonEncoder.withIndent('  ').convert(message);
  }
}
