import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/equipment_connection_config.dart';
import 'audit_service.dart';
import 'auth_service.dart';
import 'equipment_protocol_service.dart';
import 'file_watch_service.dart';
import 'lab_repository.dart';
import 'result_import_service.dart';
import 'serial_port_service.dart';
import 'tcp_connection_service.dart';

class EquipmentConnectionService {
  EquipmentConnectionService._();
  static final EquipmentConnectionService instance =
      EquipmentConnectionService._();
  final LabRepository _repo = LabRepository();

  Future<List<EquipmentConnectionConfig>> listar() async {
    final List<Map<String, dynamic>> rows =
        await _repo.all('equipment_connections');
    return rows
        .map((Map<String, dynamic> row) =>
            EquipmentConnectionConfig.fromMap(row))
        .toList();
  }

  Future<void> salvar({
    required AuthSession session,
    required EquipmentConnectionConfig config,
  }) async {
    if (!session.isAdmin) {
      throw StateError(
        'Somente Superusuário ou Administrador pode configurar equipamentos.',
      );
    }
    final String now = DateTime.now().toIso8601String();
    final EquipmentConnectionConfig normalized = config.copyWith(
      atualizadoEm: now,
      criadoEm: config.criadoEm.isEmpty ? now : config.criadoEm,
    );
    await _repo.upsert(
      'equipment_connections',
      normalized.toMap(),
      usuario: session.login,
    );
    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'CONFIGURAR_COMUNICACAO_EQUIPAMENTO',
      tabela: 'equipment_connections',
      registroId: normalized.id,
      detalhes:
          '${normalized.nome} | ${normalized.tipoConexao} | ${normalized.protocolo}',
    );
  }

  Future<void> excluir({
    required AuthSession session,
    required String id,
  }) async {
    if (!session.isAdmin) {
      throw StateError(
        'Somente Superusuário ou Administrador pode arquivar configuração.',
      );
    }
    await _repo.archiveWithoutDelete(
      'equipment_connections',
      id,
      usuario: session.login,
    );
    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'ARQUIVAR_COMUNICACAO_EQUIPAMENTO',
      tabela: 'equipment_connections',
      registroId: id,
      detalhes: 'Configuração arquivada sem exclusão física.',
    );
  }

  Future<String> testarConexao(EquipmentConnectionConfig config) async {
    if (!config.isAtivo) return 'Equipamento inativo. Ative antes de testar.';
    if (config.isTcpIp) {
      return (await TcpConnectionService.instance.testar(config)).message;
    }
    if (config.isPastaArquivo) {
      return (await FileWatchService.instance.listarArquivosPendentes(config))
          .message;
    }
    if (config.isSerialUsb) {
      return (await SerialPortService.instance.testar(config)).message;
    }
    if (config.isDriverExterno) return _testarDriver(config);
    return 'Tipo de conexão não reconhecido: ${config.tipoConexao}';
  }

  Future<String> enviarWorklist({
    required EquipmentConnectionConfig config,
    required String sampleId,
    required String patientId,
    required String patientName,
    required List<String> exames,
    String usuario = 'SISTEMA',
  }) async {
    if (!config.isAtivo) {
      throw StateError('Equipamento ${config.nome} está inativo.');
    }
    if (sampleId.trim().isEmpty || patientId.trim().isEmpty || exames.isEmpty) {
      throw ArgumentError(
        'Amostra, paciente e ao menos um exame são obrigatórios para a worklist.',
      );
    }
    final String message = config.protocolo.toUpperCase().contains('HL7')
        ? EquipmentProtocolService.instance.gerarWorklistHl7Orm(
            sampleId: sampleId,
            patientId: patientId,
            patientName: patientName,
            exames: exames,
          )
        : EquipmentProtocolService.instance.gerarWorklistAstm(
            sampleId: sampleId,
            patientId: patientId,
            patientName: patientName,
            exames: exames,
          );

    String status;
    if (config.isTcpIp) {
      final TcpConnectionResult result =
          await TcpConnectionService.instance.enviarMensagem(
        config: config,
        mensagem: message,
      );
      status = result.message;
      await _recordMessage(
        config: config,
        direction: 'SAIDA',
        sampleId: sampleId,
        payload: message,
        status: result.ok ? 'ENVIADO' : 'ERRO',
        error: result.ok ? '' : result.message,
        usuario: usuario,
      );
      return status;
    }
    if (config.isPastaArquivo) {
      status = await _salvarWorklistEmPasta(config, message, sampleId);
      await _recordMessage(
        config: config,
        direction: 'SAIDA',
        sampleId: sampleId,
        payload: message,
        status: 'GRAVADO',
        error: '',
        usuario: usuario,
      );
      return status;
    }
    if (config.isSerialUsb) {
      final SerialPortResult result =
          await SerialPortService.instance.enviarMensagem(
        config: config,
        mensagem: message,
      );
      await _recordMessage(
        config: config,
        direction: 'SAIDA',
        sampleId: sampleId,
        payload: message,
        status: result.ok ? 'ENVIADO' : 'ERRO',
        error: result.ok ? '' : result.message,
        usuario: usuario,
      );
      return result.message;
    }
    if (config.isDriverExterno) {
      throw StateError(
        'Driver externo não possui contrato de envio homologado: ${config.executavelPath}',
      );
    }
    throw StateError('Tipo de conexão não suportado: ${config.tipoConexao}.');
  }

  Future<List<Map<String, dynamic>>> importarResultadosPasta(
    EquipmentConnectionConfig config, {
    String usuario = 'SISTEMA',
  }) async {
    final FileWatchResult pending =
        await FileWatchService.instance.listarArquivosPendentes(config);
    if (!pending.ok) throw StateError(pending.message);
    final List<Map<String, dynamic>> imported = <Map<String, dynamic>>[];
    for (final File file in pending.files) {
      final String raw = await FileWatchService.instance.lerArquivo(file);
      final Map<String, dynamic> result =
          await ResultImportService.instance.importarMensagem(
        equipmentId: config.id,
        protocolo: config.protocolo,
        mensagem: raw,
        usuario: usuario,
      );
      await FileWatchService.instance.moverParaProcessados(
        file: file,
        config: config,
      );
      imported.add(<String, dynamic>{...result, 'arquivo': file.path});
    }
    return imported;
  }

  Future<Map<String, dynamic>> importarResultadoSerial(
    EquipmentConnectionConfig config, {
    String usuario = 'SISTEMA',
  }) async {
    final SerialPortResult received =
        await SerialPortService.instance.receberMensagem(config: config);
    if (!received.ok) throw StateError(received.message);
    if (received.data.isEmpty) {
      throw StateError('Nenhum dado recebido de ${config.portaCom}.');
    }
    return ResultImportService.instance.importarMensagem(
      equipmentId: config.id,
      protocolo: config.protocolo,
      mensagem: received.data,
      usuario: usuario,
    );
  }

  Future<String> _testarDriver(EquipmentConnectionConfig config) async {
    if (config.driverPath.trim().isNotEmpty &&
        !await File(config.driverPath.trim()).exists()) {
      return 'Arquivo de driver não encontrado: ${config.driverPath}';
    }
    if (config.executavelPath.trim().isNotEmpty &&
        !await File(config.executavelPath.trim()).exists()) {
      return 'Executável externo não encontrado: ${config.executavelPath}';
    }
    return 'Arquivos localizados. A homologação do protocolo do fabricante ainda é obrigatória.';
  }

  Future<String> _salvarWorklistEmPasta(
    EquipmentConnectionConfig config,
    String mensagem,
    String sampleId,
  ) async {
    if (config.pastaSaida.trim().isEmpty) {
      throw ArgumentError('Informe a pasta de saída para gravar a worklist.');
    }
    final Directory output = Directory(config.pastaSaida.trim());
    if (!await output.exists()) await output.create(recursive: true);
    final String path =
        '${output.path}${Platform.pathSeparator}WL_$sampleId.txt';
    await File(path).writeAsString(mensagem, encoding: latin1, flush: true);
    return 'Worklist gerada em: $path';
  }

  Future<void> _recordMessage({
    required EquipmentConnectionConfig config,
    required String direction,
    required String sampleId,
    required String payload,
    required String status,
    required String error,
    required String usuario,
  }) async {
    final String hash = sha256.convert(utf8.encode(payload)).toString();
    await _repo.upsert(
      'equipment_messages',
      <String, dynamic>{
        'id': 'EQMSG-$hash',
        'equipmentId': config.id,
        'protocolo': config.protocolo,
        'direcao': direction,
        'sampleId': sampleId,
        'payload': payload,
        'sha256': hash,
        'status': status,
        'erro': error,
        'criadoEm': DateTime.now().toIso8601String(),
        'processadoEm': DateTime.now().toIso8601String(),
        'ativoConsultaRecente': '1',
        'arquivado': '0',
      },
      usuario: usuario,
    );
  }
}
