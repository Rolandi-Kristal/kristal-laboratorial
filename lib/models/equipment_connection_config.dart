class EquipmentConnectionConfig {
  final String id;
  final String nome;
  final String fabricante;
  final String modelo;
  final String setor;
  final String tipoConexao;
  final String protocolo;
  final String ip;
  final String portaTcp;
  final String portaCom;
  final String baudRate;
  final String dataBits;
  final String stopBits;
  final String paridade;
  final String handshake;
  final String pastaEntrada;
  final String pastaSaida;
  final String extensoesMonitoradas;
  final String driverPath;
  final String executavelPath;
  final String timeoutSegundos;
  final String ativo;
  final String observacao;
  final String criadoEm;
  final String atualizadoEm;

  const EquipmentConnectionConfig({
    required this.id,
    required this.nome,
    required this.fabricante,
    required this.modelo,
    required this.setor,
    required this.tipoConexao,
    required this.protocolo,
    required this.ip,
    required this.portaTcp,
    required this.portaCom,
    required this.baudRate,
    required this.dataBits,
    required this.stopBits,
    required this.paridade,
    required this.handshake,
    required this.pastaEntrada,
    required this.pastaSaida,
    required this.extensoesMonitoradas,
    required this.driverPath,
    required this.executavelPath,
    required this.timeoutSegundos,
    required this.ativo,
    required this.observacao,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  bool get isAtivo => ativo == '1';
  bool get isTcpIp => tipoConexao.toUpperCase() == 'TCP_IP';
  bool get isSerialUsb => tipoConexao.toUpperCase() == 'SERIAL_USB';
  bool get isPastaArquivo => tipoConexao.toUpperCase() == 'PASTA_ARQUIVO';
  bool get isDriverExterno => tipoConexao.toUpperCase() == 'DRIVER_EXTERNO';
  int get portaTcpInt => int.tryParse(portaTcp.trim()) ?? 0;
  int get timeoutInt => int.tryParse(timeoutSegundos.trim()) ?? 8;

  factory EquipmentConnectionConfig.empty() {
    final String now = DateTime.now().toIso8601String();
    return EquipmentConnectionConfig(
      id: 'EQCONN-${DateTime.now().microsecondsSinceEpoch}',
      nome: '',
      fabricante: '',
      modelo: '',
      setor: '',
      tipoConexao: 'TCP_IP',
      protocolo: 'ASTM',
      ip: '',
      portaTcp: '',
      portaCom: 'COM1',
      baudRate: '9600',
      dataBits: '8',
      stopBits: '1',
      paridade: 'NONE',
      handshake: 'NONE',
      pastaEntrada: '',
      pastaSaida: '',
      extensoesMonitoradas: '.txt,.csv,.astm,.hl7',
      driverPath: '',
      executavelPath: '',
      timeoutSegundos: '8',
      ativo: '1',
      observacao: '',
      criadoEm: now,
      atualizadoEm: now,
    );
  }

  factory EquipmentConnectionConfig.fromMap(Map<String, dynamic> map) {
    return EquipmentConnectionConfig(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      fabricante: map['fabricante']?.toString() ?? '',
      modelo: map['modelo']?.toString() ?? '',
      setor: map['setor']?.toString() ?? '',
      tipoConexao: map['tipoConexao']?.toString() ?? 'TCP_IP',
      protocolo: map['protocolo']?.toString() ?? 'ASTM',
      ip: map['ip']?.toString() ?? '',
      portaTcp: map['portaTcp']?.toString() ?? '',
      portaCom: map['portaCom']?.toString() ?? 'COM1',
      baudRate: map['baudRate']?.toString() ?? '9600',
      dataBits: map['dataBits']?.toString() ?? '8',
      stopBits: map['stopBits']?.toString() ?? '1',
      paridade: map['paridade']?.toString() ?? 'NONE',
      handshake: map['handshake']?.toString() ?? 'NONE',
      pastaEntrada: map['pastaEntrada']?.toString() ?? '',
      pastaSaida: map['pastaSaida']?.toString() ?? '',
      extensoesMonitoradas:
          map['extensoesMonitoradas']?.toString() ?? '.txt,.csv,.astm,.hl7',
      driverPath: map['driverPath']?.toString() ?? '',
      executavelPath: map['executavelPath']?.toString() ?? '',
      timeoutSegundos: map['timeoutSegundos']?.toString() ?? '8',
      ativo: map['ativo']?.toString() ?? '1',
      observacao: map['observacao']?.toString() ?? '',
      criadoEm: map['criadoEm']?.toString() ?? '',
      atualizadoEm: map['atualizadoEm']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'nome': nome,
        'fabricante': fabricante,
        'modelo': modelo,
        'setor': setor,
        'tipoConexao': tipoConexao,
        'protocolo': protocolo,
        'ip': ip,
        'portaTcp': portaTcp,
        'portaCom': portaCom,
        'baudRate': baudRate,
        'dataBits': dataBits,
        'stopBits': stopBits,
        'paridade': paridade,
        'handshake': handshake,
        'pastaEntrada': pastaEntrada,
        'pastaSaida': pastaSaida,
        'extensoesMonitoradas': extensoesMonitoradas,
        'driverPath': driverPath,
        'executavelPath': executavelPath,
        'timeoutSegundos': timeoutSegundos,
        'ativo': ativo,
        'observacao': observacao,
        'criadoEm': criadoEm,
        'atualizadoEm': atualizadoEm,
      };

  EquipmentConnectionConfig copyWith({
    String? id,
    String? nome,
    String? fabricante,
    String? modelo,
    String? setor,
    String? tipoConexao,
    String? protocolo,
    String? ip,
    String? portaTcp,
    String? portaCom,
    String? baudRate,
    String? dataBits,
    String? stopBits,
    String? paridade,
    String? handshake,
    String? pastaEntrada,
    String? pastaSaida,
    String? extensoesMonitoradas,
    String? driverPath,
    String? executavelPath,
    String? timeoutSegundos,
    String? ativo,
    String? observacao,
    String? criadoEm,
    String? atualizadoEm,
  }) {
    return EquipmentConnectionConfig(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      fabricante: fabricante ?? this.fabricante,
      modelo: modelo ?? this.modelo,
      setor: setor ?? this.setor,
      tipoConexao: tipoConexao ?? this.tipoConexao,
      protocolo: protocolo ?? this.protocolo,
      ip: ip ?? this.ip,
      portaTcp: portaTcp ?? this.portaTcp,
      portaCom: portaCom ?? this.portaCom,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      stopBits: stopBits ?? this.stopBits,
      paridade: paridade ?? this.paridade,
      handshake: handshake ?? this.handshake,
      pastaEntrada: pastaEntrada ?? this.pastaEntrada,
      pastaSaida: pastaSaida ?? this.pastaSaida,
      extensoesMonitoradas: extensoesMonitoradas ?? this.extensoesMonitoradas,
      driverPath: driverPath ?? this.driverPath,
      executavelPath: executavelPath ?? this.executavelPath,
      timeoutSegundos: timeoutSegundos ?? this.timeoutSegundos,
      ativo: ativo ?? this.ativo,
      observacao: observacao ?? this.observacao,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}
