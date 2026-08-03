import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class PortalPatientSyncResult {
  final String codigo;
  final String mensagem;

  const PortalPatientSyncResult({
    required this.codigo,
    required this.mensagem,
  });
}

class PortalPatientSyncService {
  PortalPatientSyncService._();

  static final PortalPatientSyncService instance = PortalPatientSyncService._();

  String get portalDbPath {
    return p.join(Directory.current.path, 'portal_web', 'data', 'kristal_portal.db');
  }

  String gerarCodigoAcesso() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random.secure();
    return List<String>.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  Future<PortalPatientSyncResult> sincronizarPaciente({
    required Map<String, dynamic> paciente,
    String? codigoAcesso,
  }) async {
    final String nome = paciente['nome']?.toString().trim() ?? '';
    final String cpf = _digits(paciente['cpf']?.toString() ?? '');
    if (nome.isEmpty) {
      throw ArgumentError('Informe o nome do paciente antes de sincronizar.');
    }
    if (cpf.isEmpty) {
      throw ArgumentError('Informe o CPF do paciente antes de sincronizar.');
    }

    final String codigo = (codigoAcesso?.trim().isNotEmpty == true)
        ? codigoAcesso!.trim()
        : gerarCodigoAcesso();

    final File dbFile = File(portalDbPath);
    if (!await dbFile.exists()) {
      throw StateError('Banco do portal nao encontrado: $portalDbPath');
    }

    sqfliteFfiInit();
    final Database db = await databaseFactoryFfi.openDatabase(portalDbPath);
    final String now = DateTime.now().toIso8601String();

    try {
      final List<Map<String, Object?>> existing = await db.query(
        'pacientes',
        columns: <String>['id'],
        where: 'cpf = ?',
        whereArgs: <Object?>[cpf],
        limit: 1,
      );

      final String id = existing.isNotEmpty
          ? existing.first['id']?.toString() ?? ''
          : 'PAC-${DateTime.now().microsecondsSinceEpoch}';

      final Map<String, Object?> data = <String, Object?>{
        'id': id,
        'nome': nome,
        'cpf': cpf,
        'preccp': paciente['preccp']?.toString() ?? '',
        'cns': paciente['cns']?.toString() ?? '',
        'nascimento': paciente['nascimento']?.toString() ?? '',
        'telefone': paciente['telefone']?.toString() ?? '',
        'email': paciente['email']?.toString() ?? '',
        'codigo_acesso_hash': await _hashPassword(codigo),
        'ativo': '1',
        'ativo_consulta_recente': '1',
        'arquivado': '0',
        'excluido_fisicamente': '0',
        'criado_em': existing.isNotEmpty ? now : now,
        'atualizado_em': now,
      };

      await db.insert(
        'pacientes',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } finally {
      await db.close();
    }

    return PortalPatientSyncResult(
      codigo: codigo,
      mensagem: 'Paciente sincronizado no portal. Codigo: $codigo',
    );
  }

  Future<String> _hashPassword(String password) async {
    final List<int> salt = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    );
    const int iterations = 210000;
    final Pbkdf2 pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final SecretKey key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final List<int> digest = await key.extractBytes();
    final String saltB64 = base64Url.encode(salt);
    final String digestB64 = base64Url.encode(digest);
    return 'pbkdf2_sha256\$$iterations\$$saltB64\$$digestB64';
  }

  String _digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
}
