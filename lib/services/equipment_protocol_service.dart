class EquipmentProtocolService {
  EquipmentProtocolService._();

  static final EquipmentProtocolService instance = EquipmentProtocolService._();

  String gerarWorklistAstm({
    required String sampleId,
    required String patientId,
    required String patientName,
    required List<String> exames,
  }) {
    final String now = DateTime.now().toIso8601String();
    final String exams = exames.join('^');

    return '''
H|\\^&|||KRISTAL_LAB|||||LIS||P|1|$now
P|1|$patientId||$patientName||||||||||||||||||||||||||||
O|1|$sampleId||$exams|R||||||||||||||||||||||F
L|1|N
'''
        .replaceAll('\n', '\r');
  }

  String gerarWorklistHl7Orm({
    required String sampleId,
    required String patientId,
    required String patientName,
    required List<String> exames,
  }) {
    final String now = DateTime.now()
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .split('.')
        .first;

    final String controlId = 'KRISTAL$now';
    final String exams = exames.join('^');

    return '''
MSH|^~\\&|KRISTAL_LAB|HMR|EQUIPAMENTO|LAB|$now||ORM^O01|$controlId|P|2.3.1
PID|1||$patientId||$patientName
ORC|NW|$sampleId
OBR|1|$sampleId||$exams
'''
        .replaceAll('\n', '\r');
  }

  Map<String, dynamic> parseResultadoAstm(String raw) {
    final List<String> lines = raw
        .split(RegExp(r'[\r\n]+'))
        .where((String e) => e.trim().isNotEmpty)
        .toList();

    final List<Map<String, String>> resultados = <Map<String, String>>[];
    String sampleId = '';

    for (final String line in lines) {
      final List<String> parts = line.split('|');

      if (parts.isEmpty) continue;

      if (parts.first == 'O' && parts.length > 2) {
        sampleId = parts[2];
      }

      if (parts.first == 'R' && parts.length > 4) {
        resultados.add(
          <String, String>{
            'exame': parts.length > 2 ? parts[2] : '',
            'valor': parts.length > 3 ? parts[3] : '',
            'unidade': parts.length > 4 ? parts[4] : '',
            'referencia': parts.length > 5 ? parts[5] : '',
          },
        );
      }
    }

    return <String, dynamic>{
      'protocolo': 'ASTM',
      'sampleId': sampleId,
      'resultados': resultados,
      'raw': raw,
    };
  }

  Map<String, dynamic> parseResultadoHl7(String raw) {
    final List<String> lines = raw
        .split(RegExp(r'[\r\n]+'))
        .where((String e) => e.trim().isNotEmpty)
        .toList();

    final List<Map<String, String>> resultados = <Map<String, String>>[];
    String sampleId = '';
    String patientId = '';

    for (final String line in lines) {
      final List<String> parts = line.split('|');

      if (parts.isEmpty) continue;

      if (parts.first == 'PID' && parts.length > 3) {
        patientId = parts[3];
      }

      if (parts.first == 'OBR' && parts.length > 3) {
        sampleId = parts[3];
      }

      if (parts.first == 'OBX' && parts.length > 5) {
        resultados.add(
          <String, String>{
            'exame': parts.length > 3 ? parts[3] : '',
            'valor': parts.length > 5 ? parts[5] : '',
            'unidade': parts.length > 6 ? parts[6] : '',
            'referencia': parts.length > 7 ? parts[7] : '',
          },
        );
      }
    }

    return <String, dynamic>{
      'protocolo': 'HL7',
      'sampleId': sampleId,
      'patientId': patientId,
      'resultados': resultados,
      'raw': raw,
    };
  }

  Map<String, dynamic> parseCsv(String raw) {
    final List<String> lines = raw
        .split(RegExp(r'[\r\n]+'))
        .where((String e) => e.trim().isNotEmpty)
        .toList();

    final List<Map<String, String>> resultados = <Map<String, String>>[];

    for (final String line in lines) {
      final List<String> parts =
          line.contains(';') ? line.split(';') : line.split(',');

      if (parts.length < 2) continue;

      resultados.add(
        <String, String>{
          'exame': parts[0].trim(),
          'valor': parts.length > 1 ? parts[1].trim() : '',
          'unidade': parts.length > 2 ? parts[2].trim() : '',
          'referencia': parts.length > 3 ? parts[3].trim() : '',
        },
      );
    }

    return <String, dynamic>{
      'protocolo': 'CSV',
      'resultados': resultados,
      'raw': raw,
    };
  }

  Map<String, dynamic> parseTxt(String raw) {
    final List<String> lines = raw
        .split(RegExp(r'[\r\n]+'))
        .where((String e) => e.trim().isNotEmpty)
        .toList();

    final List<Map<String, String>> resultados = <Map<String, String>>[];

    for (final String line in lines) {
      final List<String> parts = line.split(RegExp(r'[:=;|,]'));

      if (parts.length < 2) continue;

      resultados.add(
        <String, String>{
          'exame': parts[0].trim(),
          'valor': parts[1].trim(),
          'unidade': parts.length > 2 ? parts[2].trim() : '',
          'referencia': parts.length > 3 ? parts[3].trim() : '',
        },
      );
    }

    return <String, dynamic>{
      'protocolo': 'TXT',
      'resultados': resultados,
      'raw': raw,
    };
  }

  Map<String, dynamic> parseResultado({
    required String protocolo,
    required String raw,
  }) {
    final String normalized = protocolo.trim().toUpperCase();

    if (normalized.contains('HL7')) {
      return parseResultadoHl7(raw);
    }

    if (normalized.contains('CSV')) {
      return parseCsv(raw);
    }

    if (normalized.contains('TXT')) {
      return parseTxt(raw);
    }

    return parseResultadoAstm(raw);
  }
}