import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'database_service.dart';

class AuditService {
  AuditService._();

  static final AuditService instance = AuditService._();

  Future<void> registrar({
    required String acao,
    required String tabela,
    required String registroId,
    required String detalhes,
    String usuario = 'SISTEMA',
  }) async {
    final db = await DatabaseService.instance.database;
    final String now = DateTime.now().toIso8601String();

    final String id = sha256
        .convert(
          utf8.encode('$usuario|$acao|$tabela|$registroId|$now|$detalhes'),
        )
        .toString();

    await db.insert('auditoria', <String, Object?>{
      'id': id,
      'usuario': usuario,
      'acao': acao,
      'tabela': tabela,
      'registroId': registroId,
      'dataHora': now,
      'detalhes': detalhes,
    });
  }
}
