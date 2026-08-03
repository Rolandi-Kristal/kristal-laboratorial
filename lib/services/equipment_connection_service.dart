import 'dart:io';
import '../models/equipment_connection_config.dart';
import 'audit_service.dart';
import 'auth_service.dart';
import 'equipment_protocol_service.dart';
import 'file_watch_service.dart';
import 'lab_repository.dart';
import 'tcp_connection_service.dart';

class EquipmentConnectionService {
  EquipmentConnectionService._();
  static final EquipmentConnectionService instance = EquipmentConnectionService._();
  final LabRepository _repo = LabRepository();

  Future<List<EquipmentConnectionConfig>> listar() async {
    final List<Map<String, dynamic>> rows = await _repo.all('equipment_connections');
    return rows.map((row) => EquipmentConnectionConfig.fromMap(row)).toList();
  }

  Future<void> salvar({required AuthSession session, required EquipmentConnectionConfig config}) async {
    if (!session.isAdmin) throw StateError('Somente Superusuário ou Administrador pode configurar equipamentos.');
    final String now = DateTime.now().toIso8601String();
    final EquipmentConnectionConfig normalized = config.copyWith(atualizadoEm: now, criadoEm: config.criadoEm.isEmpty ? now : config.criadoEm);
    await _repo.upsert('equipment_connections', normalized.toMap());
    await AuditService.instance.registrar(usuario: session.login, acao: 'CONFIGURAR_COMUNICACAO_EQUIPAMENTO', tabela: 'equipment_connections', registroId: normalized.id, detalhes: '${normalized.nome} | ${normalized.tipoConexao} | ${normalized.protocolo}');
  }

  Future<void> excluir({required AuthSession session, required String id}) async {
    if (!session.isAdmin) throw StateError('Somente Superusuário ou Administrador pode excluir configuração.');
    await _repo.archiveWithoutDelete('equipment_connections', id, usuario: 'sistema');
    await AuditService.instance.registrar(usuario: session.login, acao: 'EXCLUIR_COMUNICACAO_EQUIPAMENTO', tabela: 'equipment_connections', registroId: id, detalhes: 'Configuração removida.');
  }

  Future<String> testarConexao(EquipmentConnectionConfig config) async {
    if (!config.isAtivo) return 'Equipamento inativo. Ative antes de testar.';
    if (config.isTcpIp) return (await TcpConnectionService.instance.testar(config)).message;
    if (config.isPastaArquivo) return (await FileWatchService.instance.listarArquivosPendentes(config)).message;
    if (config.isSerialUsb) return _testarSerial(config);
    if (config.isDriverExterno) return _testarDriver(config);
    return 'Tipo de conexão não reconhecido: ${config.tipoConexao}';
  }

  Future<String> enviarWorklist({required EquipmentConnectionConfig config, required String sampleId, required String patientId, required String patientName, required List<String> exames}) async {
    final String msg = config.protocolo.toUpperCase().contains('HL7')
        ? EquipmentProtocolService.instance.gerarWorklistHl7Orm(sampleId: sampleId, patientId: patientId, patientName: patientName, exames: exames)
        : EquipmentProtocolService.instance.gerarWorklistAstm(sampleId: sampleId, patientId: patientId, patientName: patientName, exames: exames);
    if (config.isTcpIp) return (await TcpConnectionService.instance.enviarMensagem(config: config, mensagem: msg)).message;
    if (config.isPastaArquivo) return _salvarWorklistEmPasta(config, msg, sampleId);
    if (config.isSerialUsb) return 'Worklist serial/USB preparada. Para envio físico direto por COM, instale biblioteca serial compatível com Windows.';
    if (config.isDriverExterno) return 'Driver/interface externa configurado. O envio depende do protocolo do fabricante: ${config.executavelPath}';
    return 'Tipo de conexão não suportado para worklist.';
  }

  Future<List<Map<String, dynamic>>> importarResultadosPasta(EquipmentConnectionConfig config) async {
    final FileWatchResult pending = await FileWatchService.instance.listarArquivosPendentes(config);
    if (!pending.ok) throw StateError(pending.message);
    final List<Map<String, dynamic>> parsed = <Map<String, dynamic>>[];
    for (final File file in pending.files) {
      final String raw = await FileWatchService.instance.lerArquivo(file);
      parsed.add(<String, dynamic>{...EquipmentProtocolService.instance.parseResultado(protocolo: config.protocolo, raw: raw), 'arquivo': file.path, 'equipamentoId': config.id, 'equipamentoNome': config.nome});
      await FileWatchService.instance.moverParaProcessados(file: file, config: config);
    }
    return parsed;
  }

  Future<String> _testarSerial(EquipmentConnectionConfig config) async {
    if (config.portaCom.trim().isEmpty) return 'Informe a porta COM. Exemplo: COM1, COM2, COM3.';
    return 'Configuração serial cadastrada: ${config.portaCom}, ${config.baudRate}, ${config.dataBits}${config.paridade}${config.stopBits}. Para teste físico direto, instale biblioteca serial Windows.';
  }

  Future<String> _testarDriver(EquipmentConnectionConfig config) async {
    if (config.driverPath.trim().isNotEmpty && !await File(config.driverPath.trim()).exists()) return 'Arquivo de driver não encontrado: ${config.driverPath}';
    if (config.executavelPath.trim().isNotEmpty && !await File(config.executavelPath.trim()).exists()) return 'Executável externo não encontrado: ${config.executavelPath}';
    return 'Driver/interface externa localizado e configurado.';
  }

  Future<String> _salvarWorklistEmPasta(EquipmentConnectionConfig config, String mensagem, String sampleId) async {
    if (config.pastaSaida.trim().isEmpty) return 'Informe a pasta de saída para gravar a worklist.';
    final Directory output = Directory(config.pastaSaida.trim());
    if (!await output.exists()) await output.create(recursive: true);
    final String path = '${output.path}${Platform.pathSeparator}WL_$sampleId.txt';
    await File(path).writeAsString(mensagem);
    return 'Worklist gerada em: $path';
  }
}
