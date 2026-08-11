import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'audit_service.dart';
import 'equipment_protocol_service.dart';
import 'equipment_result_mapping_service.dart';
import 'lab_repository.dart';
import 'resultados_service.dart';

class ResultImportService {
  ResultImportService({
    LabRepository? repository,
    EquipmentResultMappingService? mappingService,
  })  : _repository = repository ?? LabRepository(),
        _mappingService = mappingService ?? EquipmentResultMappingService();

  static final ResultImportService instance = ResultImportService();

  final LabRepository _repository;
  final EquipmentResultMappingService _mappingService;

  Future<Map<String, dynamic>> importarMensagem({
    required String equipmentId,
    required String protocolo,
    required String mensagem,
    String usuario = 'SISTEMA',
  }) async {
    final String equipment = equipmentId.trim();
    final String protocol = protocolo.trim().toUpperCase();
    if (equipment.isEmpty) {
      throw ArgumentError.value(
          equipmentId, 'equipmentId', 'Informe o equipamento.');
    }
    if (protocol.isEmpty) {
      throw ArgumentError.value(protocolo, 'protocolo', 'Informe o protocolo.');
    }
    if (mensagem.isEmpty) {
      throw ArgumentError.value(mensagem, 'mensagem', 'A mensagem está vazia.');
    }
    if (utf8.encode(mensagem).length > 16 * 1024 * 1024) {
      throw RangeError('Mensagem de equipamento excede o limite de 16 MiB.');
    }

    final Map<String, dynamic> parsed = EquipmentProtocolService.instance
        .parseResultado(protocolo: protocol, raw: mensagem);
    final String sampleCode = (parsed['sampleId'] ?? '').toString().trim();
    final Object? parsedResults = parsed['resultados'];
    if (sampleCode.isEmpty) {
      throw const FormatException(
          'Mensagem sem identificação da amostra/atendimento.');
    }
    if (parsedResults is! List || parsedResults.isEmpty) {
      throw const FormatException(
          'Mensagem sem resultados laboratoriais válidos.');
    }

    final String receivedAt = DateTime.now().toIso8601String();
    final String messageHash = sha256.convert(utf8.encode(mensagem)).toString();
    final String messageId = 'EQMSG-$messageHash';
    await _repository.upsert(
      'equipment_messages',
      <String, dynamic>{
        'id': messageId,
        'equipmentId': equipment,
        'protocolo': protocol,
        'direcao': 'ENTRADA',
        'sampleId': sampleCode,
        'payload': mensagem,
        'sha256': messageHash,
        'status': 'RECEBIDO',
        'erro': '',
        'criadoEm': receivedAt,
        'ativoConsultaRecente': '1',
        'arquivado': '0',
      },
      usuario: usuario,
    );

    try {
      final Map<String, dynamic> sample = await _findUniqueSample(sampleCode);
      final List<Map<String, dynamic>> imported = <Map<String, dynamic>>[];
      for (int index = 0; index < parsedResults.length; index++) {
        final Object? rawResult = parsedResults[index];
        if (rawResult is! Map) {
          throw FormatException('Resultado $index possui estrutura inválida.');
        }
        final Map<String, dynamic> item = rawResult.map(
          (Object? key, Object? value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        );
        final String sourceCode = (item['exame'] ?? '').toString().trim();
        final String rawValue = (item['valor'] ?? '').toString();
        if (sourceCode.isEmpty || rawValue.isEmpty) {
          throw FormatException('Resultado $index sem código ou valor.');
        }
        final EquipmentResultMapping mapping = await _mappingService.resolve(
          equipmentId: equipment,
          sourceCode: sourceCode,
        );
        final String sampleExamId = (sample['exameId'] ?? '').toString().trim();
        if (sampleExamId.isNotEmpty && sampleExamId != mapping.examId) {
          throw StateError(
            'O exame ${mapping.examId} não corresponde à amostra $sampleCode ($sampleExamId).',
          );
        }

        final String resultId = _resultId(
          messageHash: messageHash,
          index: index,
          sampleCode: sampleCode,
          sourceCode: sourceCode,
        );
        final Map<String, dynamic> result = <String, dynamic>{
          'id': resultId,
          'pacienteId': (sample['pacienteId'] ?? '').toString(),
          'pedidoId': (sample['pedidoId'] ?? '').toString(),
          'amostraId': (sample['id'] ?? '').toString(),
          'exameId': mapping.examId,
          'valor': rawValue,
          'valorBrutoEquipamento': rawValue,
          'mensagemBrutaEquipamento': mensagem,
          'codigoEquipamento': sourceCode,
          'mapeamentoEquipamentoId': mapping.mappingId,
          'hashMensagemEquipamento': messageHash,
          'equipamentoId': equipment,
          'protocoloEquipamento': protocol,
          'unidade': (item['unidade'] ?? '').toString(),
          'referencia': (item['referencia'] ?? '').toString(),
          'status': 'IMPORTADO',
          'criadoEm': receivedAt,
          'observacao':
              'Importado de $equipment via $protocol; valor bruto preservado.',
        };
        await ResultadosService.instance.salvarResultado(
          resultado: result,
          usuario: usuario,
        );
        imported.add(result);
      }

      await _repository.upsert(
        'equipment_messages',
        <String, dynamic>{
          'id': messageId,
          'equipmentId': equipment,
          'protocolo': protocol,
          'direcao': 'ENTRADA',
          'sampleId': sampleCode,
          'payload': mensagem,
          'sha256': messageHash,
          'status': 'PROCESSADO',
          'erro': '',
          'criadoEm': receivedAt,
          'processadoEm': DateTime.now().toIso8601String(),
          'ativoConsultaRecente': '1',
          'arquivado': '0',
        },
        usuario: usuario,
      );
      await AuditService.instance.registrar(
        usuario: usuario,
        acao: 'IMPORTAR_RESULTADOS_EQUIPAMENTO',
        tabela: 'resultados',
        registroId: messageId,
        detalhes:
            '${imported.length} resultado(s) importado(s) de $equipment via $protocol; SHA-256 $messageHash.',
      );
      return <String, dynamic>{
        'messageId': messageId,
        'hash': messageHash,
        'equipmentId': equipment,
        'sampleId': sampleCode,
        'quantidade': imported.length,
        'resultados': imported,
      };
    } on ArgumentError catch (error) {
      await _markFailed(messageId, error.message.toString(), usuario);
      rethrow;
    } on FormatException catch (error) {
      await _markFailed(messageId, error.message, usuario);
      rethrow;
    } on StateError catch (error) {
      await _markFailed(messageId, error.message, usuario);
      rethrow;
    } on DatabaseException catch (error) {
      await _markFailed(messageId, error.toString(), usuario);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _findUniqueSample(String sampleCode) async {
    final List<Map<String, dynamic>> samples = await _repository.all(
      'amostras',
      where: 'id = ? OR codigoBarras = ? OR codigoManual = ?',
      whereArgs: <Object?>[sampleCode, sampleCode, sampleCode],
      limit: 2,
    );
    if (samples.isEmpty) {
      throw StateError('Amostra/atendimento $sampleCode não encontrado.');
    }
    if (samples.length > 1) {
      throw StateError('Amostra/atendimento $sampleCode está duplicado.');
    }
    return samples.single;
  }

  Future<void> _markFailed(
    String messageId,
    String error,
    String usuario,
  ) async {
    final Map<String, dynamic>? current =
        await _repository.findById('equipment_messages', messageId);
    if (current == null) return;
    await _repository.upsert(
      'equipment_messages',
      <String, dynamic>{
        ...current,
        'status': 'ERRO',
        'erro': error,
        'processadoEm': DateTime.now().toIso8601String(),
      },
      usuario: usuario,
    );
  }

  String _resultId({
    required String messageHash,
    required int index,
    required String sampleCode,
    required String sourceCode,
  }) {
    final String digest = sha256
        .convert(
          utf8.encode('$messageHash|$index|$sampleCode|$sourceCode'),
        )
        .toString();
    return 'RESULTADO-EQUIP-${digest.substring(0, 32)}';
  }
}
