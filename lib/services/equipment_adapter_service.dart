class EquipmentProfile {
  final String id;
  final String nome;
  final String modelo;
  final String protocolo;
  final String conexao;
  final String porta;
  final String ip;
  final int? baudRate;

  const EquipmentProfile({
    required this.id,
    required this.nome,
    required this.modelo,
    required this.protocolo,
    required this.conexao,
    this.porta = '',
    this.ip = '',
    this.baudRate,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'modelo': modelo,
      'protocolo': protocolo,
      'conexao': conexao,
      'porta': porta,
      'ip': ip,
      'baudRate': baudRate?.toString() ?? '',
      'ativo': '1',
      'criadoEm': DateTime.now().toIso8601String(),
    };
  }
}

class EquipmentAdapterService {
  EquipmentAdapterService._();

  static final EquipmentAdapterService instance = EquipmentAdapterService._();

  List<EquipmentProfile> perfisPadrao() {
    return const <EquipmentProfile>[
      EquipmentProfile(
        id: 'EQ-AUDMAX',
        nome: 'Audmax',
        modelo: 'Audmax',
        protocolo: 'ASTM/Arquivo',
        conexao: 'Serial/TCP/Arquivo',
      ),
      EquipmentProfile(
        id: 'EQ-AUDLYTE',
        nome: 'AUDLYTE',
        modelo: 'AUDLYTE',
        protocolo: 'Arquivo/OLD',
        conexao: 'Arquivo',
      ),
      EquipmentProfile(
        id: 'EQ-BC5380',
        nome: 'BC5380',
        modelo: 'BC5380',
        protocolo: 'ASTM',
        conexao: 'Serial/TCP',
      ),
      EquipmentProfile(
        id: 'EQ-BH5390',
        nome: 'BH-5390',
        modelo: 'BH-5390',
        protocolo: 'ASTM/Arquivo',
        conexao: 'Serial/TCP/Arquivo',
      ),
      EquipmentProfile(
        id: 'EQ-BS360E',
        nome: 'BS360E',
        modelo: 'BS360E',
        protocolo: 'ASTM/Arquivo',
        conexao: 'Serial/TCP/Arquivo',
      ),
      EquipmentProfile(
        id: 'EQ-COAGMASTER',
        nome: 'Coagmaster',
        modelo: 'Coagmaster',
        protocolo: 'ASTM/CSV',
        conexao: 'Serial/Arquivo',
      ),
      EquipmentProfile(
        id: 'EQ-LABMAXPREMIUM',
        nome: 'Labmax Premium',
        modelo: 'LabmaxPremium',
        protocolo: 'ASTM/CSV',
        conexao: 'Serial/TCP/Arquivo',
      ),
      EquipmentProfile(
        id: 'EQ-URIVISION720',
        nome: 'Urivision 720',
        modelo: 'Urivision720',
        protocolo: 'CSV/ASTM',
        conexao: 'Serial/USB/Arquivo',
      ),
      EquipmentProfile(
        id: 'EQ-COMPLAB-ADVANCED',
        nome: 'Complab Advanced',
        modelo: 'Complab Advanced',
        protocolo: 'DLL/Arquivo/SQL',
        conexao: 'Arquivo/SQL/DLL',
      ),
      EquipmentProfile(
        id: 'EQ-HYPERTERMINAL',
        nome: 'Hyper Terminal',
        modelo: 'Hyper Terminal',
        protocolo: 'Serial/COM',
        conexao: 'Serial',
      ),
    ];
  }

  Map<String, String> parseAstmResult(String message) {
    final Map<String, String> result = <String, String>{};

    final List<String> lines = message
        .split(RegExp(r'[\r\n]+'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();

    for (final String line in lines) {
      final List<String> parts = line.split('|');

      if (parts.isEmpty) continue;

      if (parts.first == 'O' && parts.length > 3) {
        result['amostraId'] = parts[2];
        result['pedidoId'] = parts.length > 3 ? parts[3] : '';
        result['exame'] = parts.length > 4 ? parts[4] : '';
      }

      if (parts.first == 'R' && parts.length > 3) {
        result['codigo'] = parts.length > 2 ? parts[2] : '';
        result['valor'] = parts.length > 3 ? parts[3] : '';
        result['unidade'] = parts.length > 4 ? parts[4] : '';
        result['referencia'] = parts.length > 5 ? parts[5] : '';
      }
    }

    return result;
  }

  Map<String, String> parseHl7Oru(String message) {
    final Map<String, String> result = <String, String>{};

    final List<String> segments = message
        .split(RegExp(r'[\r\n]+'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();

    for (final String segment in segments) {
      final List<String> parts = segment.split('|');

      if (parts.isEmpty) continue;

      if (parts.first == 'PID' && parts.length > 3) {
        result['pacienteId'] = parts[3];
      }

      if (parts.first == 'OBR' && parts.length > 3) {
        result['pedidoId'] = parts[2];
        result['amostraId'] = parts.length > 3 ? parts[3] : '';
        result['exame'] = parts.length > 4 ? parts[4] : '';
      }

      if (parts.first == 'OBX' && parts.length > 5) {
        result['codigo'] = parts[3];
        result['valor'] = parts[5];
        result['unidade'] = parts.length > 6 ? parts[6] : '';
        result['referencia'] = parts.length > 7 ? parts[7] : '';
      }
    }

    return result;
  }

  Map<String, String> parseCsvLine(String line, {String separator = ';'}) {
    final List<String> parts = line.split(separator);

    return <String, String>{
      'amostraId': parts.isNotEmpty ? parts[0] : '',
      'codigo': parts.length > 1 ? parts[1] : '',
      'valor': parts.length > 2 ? parts[2] : '',
      'unidade': parts.length > 3 ? parts[3] : '',
      'referencia': parts.length > 4 ? parts[4] : '',
    };
  }

  String buildHl7Orm({
    required String pacienteId,
    required String pedidoId,
    required String exameCodigo,
    required String amostraId,
  }) {
    final String now = DateTime.now()
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .split('.')
        .first;

    return <String>[
      'MSH|^~\\&|KRISTAL|LAB|EQUIPAMENTO|LAB|$now||ORM^O01|$pedidoId|P|2.3',
      'PID|||$pacienteId||PACIENTE^KRISTAL',
      'ORC|NW|$pedidoId',
      'OBR|1|$pedidoId|$amostraId|$exameCodigo',
    ].join('\r');
  }

  String buildAstmOrder({
    required String pacienteId,
    required String pedidoId,
    required String exameCodigo,
    required String amostraId,
  }) {
    return <String>[
      'H|\\^&|||KRISTAL LAB|||||||P|1',
      'P|1|$pacienteId||||||||||||||||||||||||||||',
      'O|1|$amostraId|$pedidoId|$exameCodigo|R||||||A||||||||||||||O',
      'L|1|N',
    ].join('\r');
  }
}
