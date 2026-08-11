import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_constants.dart';
import '../security/kristal_crypto_service.dart';
import 'database_service.dart';

class LabRepository {
  LabRepository();

  static const List<String> neverDeleteTables =
      AppConstants.protectedClinicalTables;

  static const Set<String> _sensitiveFields = <String>{
    'cpf',
    'cns',
    'preccp',
    'telefone',
    'endereco',
    'email',
    'senha',
    'password',
    'token',
    'observacao',
    'anamnese',
    'resultado',
    'valor',
    'payload',
    'mensagembruta',
  };

  Future<Database> get _database async {
    final dynamic service = DatabaseService.instance;

    try {
      final dynamic db = await service.db;
      if (db is Database) {
        return db;
      }
    } on NoSuchMethodError {
      // Compatibilidade com versões antigas que usam DatabaseService.instance.database.
    }

    final dynamic legacyDb = await service.database;
    if (legacyDb is Database) {
      return legacyDb;
    }

    throw StateError('Banco de dados KRISTAL LABORATORIAL não inicializado.');
  }

  static String newId(String prefix) {
    final DateTime now = DateTime.now();
    final String digest = sha1
        .convert(utf8.encode(
            '$prefix|${now.toIso8601String()}|${now.microsecondsSinceEpoch}'))
        .toString()
        .substring(0, 10);
    return '$prefix-${now.microsecondsSinceEpoch}-$digest';
  }

  String _safeTable(String table) {
    final String value = table.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      throw ArgumentError('Nome de tabela inválido: $table');
    }
    return value;
  }

  String _safeOrderBy(String? orderBy) {
    final String value = (orderBy ?? 'rowid DESC').trim();
    if (value.isEmpty) {
      return 'rowid DESC';
    }
    if (!RegExp(r'^[a-zA-Z0-9_,.\s-]+$').hasMatch(value)) {
      return 'rowid DESC';
    }
    return value;
  }

  Future<List<String>> columns(String table) async {
    final Database db = await _database;
    final String safeTable = _safeTable(table);
    final List<Map<String, Object?>> info =
        await db.rawQuery('PRAGMA table_info($safeTable)');
    return info
        .map((Map<String, Object?> row) => row['name'].toString())
        .toList();
  }

  Future<List<Map<String, dynamic>>> all(
    String table, {
    String? orderBy,
    int? limit,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final Database db = await _database;
    final String safeTable = _safeTable(table);

    try {
      final List<Map<String, dynamic>> rows = await db.query(
        safeTable,
        where: where,
        whereArgs: whereArgs,
        orderBy: _safeOrderBy(orderBy),
        limit: limit,
      );
      return Future.wait(rows.map(_decryptRow));
    } on DatabaseException {
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> byId(String table, String id) async {
    return findById(table, id);
  }

  Future<Map<String, dynamic>?> findById(String table, String id) async {
    if (id.trim().isEmpty) {
      return null;
    }

    final List<Map<String, dynamic>> rows = await all(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<bool> existsWhere(
    String table,
    String where,
    List<Object?> whereArgs,
  ) async {
    final List<Map<String, dynamic>> rows = await all(
      table,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    String usuario = 'sistema',
  }) async {
    final Database db = await _database;
    final String safeTable = _safeTable(table);
    final List<String> tableColumns = await columns(safeTable);
    final Map<String, dynamic> row = <String, dynamic>{};

    for (final MapEntry<String, dynamic> entry in data.entries) {
      if (tableColumns.isEmpty || tableColumns.contains(entry.key)) {
        row[entry.key] = entry.value;
      }
    }

    final String id = (row['id'] ?? '').toString().trim().isEmpty
        ? newId(safeTable.toUpperCase())
        : row['id'].toString();
    row['id'] = id;

    final String now = DateTime.now().toIso8601String();
    if (tableColumns.contains('criadoEm') &&
        (row['criadoEm']?.toString().trim().isEmpty ?? true)) {
      row['criadoEm'] = now;
    }
    if (tableColumns.contains('criado_em') &&
        (row['criado_em']?.toString().trim().isEmpty ?? true)) {
      row['criado_em'] = now;
    }
    if (tableColumns.contains('atualizadoEm')) {
      row['atualizadoEm'] = now;
    }
    if (tableColumns.contains('atualizado_em')) {
      row['atualizado_em'] = now;
    }

    await db.insert(
      safeTable,
      await _encryptRow(row),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await audit(
      usuario: usuario,
      acao: 'UPSERT',
      tabela: safeTable,
      registroId: id,
      detalhes: _maskAudit(row).toString(),
    );
  }

  Future<void> archiveWithoutDelete(
    String table,
    String id, {
    String usuario = 'sistema',
    String motivo =
        'Registro preservado permanentemente para consulta histórica.',
  }) async {
    if (id.trim().isEmpty) {
      return;
    }

    final Database db = await _database;
    final String safeTable = _safeTable(table);
    final List<String> tableColumns = await columns(safeTable);
    final Map<String, Object?> updates = <String, Object?>{};

    if (tableColumns.contains('ativoConsultaRecente')) {
      updates['ativoConsultaRecente'] = '0';
    }
    if (tableColumns.contains('ativo_consulta_recente')) {
      updates['ativo_consulta_recente'] = '0';
    }
    if (tableColumns.contains('arquivado')) {
      updates['arquivado'] = '1';
    }
    if (tableColumns.contains('motivoArquivamento')) {
      updates['motivoArquivamento'] = motivo;
    }
    if (tableColumns.contains('atualizadoEm')) {
      updates['atualizadoEm'] = DateTime.now().toIso8601String();
    }
    if (tableColumns.contains('atualizado_em')) {
      updates['atualizado_em'] = DateTime.now().toIso8601String();
    }

    if (updates.isNotEmpty) {
      await db.update(safeTable, updates,
          where: 'id = ?', whereArgs: <Object?>[id]);
    }

    await audit(
      usuario: usuario,
      acao: 'ARQUIVAR_SEM_EXCLUIR',
      tabela: safeTable,
      registroId: id,
      detalhes: motivo,
    );
  }

  Future<void> delete(
    String table,
    String id, {
    String usuario = 'sistema',
  }) async {
    final String safeTable = _safeTable(table);
    if (id.trim().isEmpty) {
      return;
    }
    await archiveWithoutDelete(
      safeTable,
      id,
      usuario: usuario,
      motivo: 'Retenção permanente: exclusão física bloqueada.',
    );
  }

  Future<int> count(String table,
      {String? where, List<Object?>? whereArgs}) async {
    final Database db = await _database;
    final String safeTable = _safeTable(table);
    final String clause =
        where == null || where.trim().isEmpty ? '' : ' WHERE $where';

    try {
      final List<Map<String, Object?>> result = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM $safeTable$clause',
        whereArgs,
      );
      if (result.isEmpty) {
        return 0;
      }

      final Object? total = result.first['total'];
      if (total is int) {
        return total;
      }
      if (total is num) {
        return total.toInt();
      }

      return int.tryParse(total?.toString() ?? '0') ?? 0;
    } on DatabaseException {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> search(
    String table,
    String field,
    String value, {
    int? limit,
  }) async {
    final String query = value.trim();
    if (query.isEmpty) {
      return all(table, limit: limit);
    }
    return all(
      table,
      where: '$field LIKE ?',
      whereArgs: <Object?>['%$query%'],
      limit: limit,
    );
  }

  Future<void> audit({
    required String usuario,
    required String acao,
    required String tabela,
    String? registroId,
    String? detalhes,
  }) async {
    final Database db = await _database;

    try {
      await db.insert(
        'auditoria',
        <String, Object?>{
          'id': newId('AUD'),
          'usuario': usuario,
          'acao': acao,
          'tabela': tabela,
          'registroId': registroId ?? '',
          'registro_id': registroId ?? '',
          'dataHora': DateTime.now().toIso8601String(),
          'data_hora': DateTime.now().toIso8601String(),
          'detalhes': detalhes ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException {
      // Auditoria não interrompe a operação principal caso a tabela antiga tenha outra estrutura.
    }
  }

  Future<Map<String, dynamic>> _encryptRow(Map<String, dynamic> row) async {
    final Map<String, dynamic> output = Map<String, dynamic>.from(row);
    for (final MapEntry<String, dynamic> entry in output.entries.toList()) {
      if (entry.value is String && _isSensitiveField(entry.key)) {
        output[entry.key] = await KristalCryptoService.instance
            .encryptString(entry.value as String);
      }
    }
    return output;
  }

  Future<Map<String, dynamic>> _decryptRow(Map<String, dynamic> row) async {
    final Map<String, dynamic> output = Map<String, dynamic>.from(row);
    for (final MapEntry<String, dynamic> entry in output.entries.toList()) {
      if (entry.value is String && _isSensitiveField(entry.key)) {
        output[entry.key] = await KristalCryptoService.instance
            .decryptString(entry.value as String);
      }
    }
    return output;
  }

  bool _isSensitiveField(String field) {
    final String normalized = field.toLowerCase();
    return _sensitiveFields.any(
      (String sensitive) => normalized.contains(sensitive.toLowerCase()),
    );
  }

  Map<String, dynamic> _maskAudit(Map<String, dynamic> row) {
    final Map<String, dynamic> output = Map<String, dynamic>.from(row);
    for (final String key in output.keys.toList()) {
      if (_isSensitiveField(key)) {
        output[key] = '***';
      }
    }
    return output;
  }
}
