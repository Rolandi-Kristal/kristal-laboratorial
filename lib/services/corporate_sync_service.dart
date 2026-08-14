import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../security/kristal_crypto_service.dart';
import 'corporate_payload_crypto_service.dart';
import 'database_service.dart';
import 'lab_repository.dart';
import 'server_config_service.dart';

class CorporateSyncResult {
  const CorporateSyncResult(this.ok, this.message,
      {this.pushed = 0, this.pulled = 0});
  final bool ok;
  final String message;
  final int pushed;
  final int pulled;
}

class CorporateInitialSyncDecision {
  const CorporateInitialSyncDecision._({required this.initialPullRequired});

  factory CorporateInitialSyncDecision.fromStoredValue(String? value) {
    return CorporateInitialSyncDecision._(
      initialPullRequired: value?.trim() != '1',
    );
  }

  final bool initialPullRequired;
}

class CorporateInitialSyncOutboxPolicy {
  const CorporateInitialSyncOutboxPolicy._();

  static bool suppressAsPreexisting({
    required int queueId,
    required int initialWatermark,
  }) =>
      queueId <= initialWatermark;
}

class _CorporatePullResult {
  const _CorporatePullResult({required this.total, required this.hasMore});

  final int total;
  final bool hasMore;
}

class CorporateSyncService {
  CorporateSyncService._();
  static final instance = CorporateSyncService._();
  static const entities = <String>[
    'pacientes',
    'exames',
    'pedidos',
    'amostras',
    'resultados',
    'laudos',
    'equipamentos',
    'usuarios',
    'auditoria',
    'materiais',
    'estoque',
    'calibracoes',
    'manutencoes',
    'controle_qualidade',
    'agendamentos',
    'cadebens_integracao',
    'atendimentos',
    'historico_exames_pacientes',
    'equipment_connections',
    'equipment_test_mappings',
    'equipment_messages'
  ];
  final LabRepository _repository = LabRepository();
  bool _running = false;

  Future<void> ensureSchema() async {
    final db = await DatabaseService.instance.database;
    await db.execute('CREATE TABLE IF NOT EXISTS corporate_sync_state '
        '(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS corporate_sync_outbox '
        '(id INTEGER PRIMARY KEY AUTOINCREMENT,entity TEXT NOT NULL,'
        'record_id TEXT NOT NULL,operation TEXT NOT NULL,created_at TEXT NOT NULL)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_outbox '
        'ON corporate_sync_outbox(entity,record_id,id)');
    await db.insert(
        'corporate_sync_state', {'key': 'applying_remote', 'value': '0'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    for (final table in entities) {
      if (!await _exists(db, table)) continue;
      final when = "COALESCE((SELECT value FROM corporate_sync_state "
          "WHERE key='applying_remote'),'0')='0'";
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        final suffix = event.substring(0, 3).toLowerCase();
        final ref = event == 'DELETE' ? 'OLD' : 'NEW';
        final op = event == 'DELETE' ? 'DELETE' : 'UPSERT';
        await db.execute("CREATE TRIGGER IF NOT EXISTS sync_${table}_$suffix "
            "AFTER $event ON $table WHEN $when BEGIN INSERT INTO "
            "corporate_sync_outbox(entity,record_id,operation,created_at) "
            "VALUES('$table',$ref.id,'$op',strftime('%Y-%m-%dT%H:%M:%fZ','now')); END");
      }
    }
    final bootstrapped = await _state(db, 'outbox_bootstrapped');
    if (bootstrapped != '1') {
      await db.transaction((txn) async {
        for (final table in entities) {
          if (!await _exists(txn, table)) continue;
          await txn.rawInsert(
            "INSERT INTO corporate_sync_outbox(entity,record_id,operation,created_at) SELECT ?,id,'UPSERT',strftime('%Y-%m-%dT%H:%M:%fZ','now') FROM $table",
            [table],
          );
        }
        await _set(txn, 'outbox_bootstrapped', '1');
      });
    }
  }

  Future<CorporateSyncResult> synchronize() async {
    if (_running) {
      return const CorporateSyncResult(true, 'Sincronização em execução.');
    }
    _running = true;
    try {
      await ensureSchema();
      final cfg = await ServerConfigService.instance.carregar();
      if (!cfg.sincronizacaoAtivaBool) {
        return const CorporateSyncResult(false, 'Sincronização desativada.');
      }
      final key = cfg.nuvemApiKey.trim().isNotEmpty
          ? cfg.nuvemApiKey.trim()
          : cfg.cloudApiToken.trim();
      if (key.isEmpty) {
        return const CorporateSyncResult(false, 'Chave API não configurada.');
      }
      final base = _base(cfg), client = await _client();
      final db = await DatabaseService.instance.database;
      final initialDecision = CorporateInitialSyncDecision.fromStoredValue(
        await _state(db, 'initial_pull_complete'),
      );
      if (initialDecision.initialPullRequired) {
        final initialWatermark = await _initialPullOutboxWatermark(db);
        final initialPull = await _pull(base, key, client);
        if (!initialPull.hasMore) {
          await db.transaction((txn) async {
            await _set(
              txn,
              'outbox_suppressed_through',
              '$initialWatermark',
            );
            await _set(txn, 'initial_pull_complete', '1');
            await _set(
              txn,
              'initial_pull_completed_at',
              DateTime.now().toUtc().toIso8601String(),
            );
          });
        }
        return CorporateSyncResult(
          true,
          initialPull.hasMore
              ? 'Carga inicial do servidor em andamento; envio local bloqueado até a conclusão.'
              : 'Carga inicial do servidor concluída; sincronização bidirecional liberada.',
          pulled: initialPull.total,
        );
      }
      final pushed = await _push(base, key, client);
      final pull = await _pull(base, key, client);
      return CorporateSyncResult(true, 'Sincronização concluída.',
          pushed: pushed, pulled: pull.total);
    } on SocketException catch (e) {
      return CorporateSyncResult(
          false, 'Servidor indisponível; fila preservada: ${e.message}');
    } on TimeoutException {
      return const CorporateSyncResult(
          false, 'Servidor excedeu o tempo limite.');
    } on HttpException catch (e) {
      return CorporateSyncResult(false, e.message);
    } on FormatException catch (e) {
      return CorporateSyncResult(false, 'Resposta inválida: ${e.message}');
    } on DatabaseException catch (e) {
      return CorporateSyncResult(false, 'Falha transacional: $e');
    } finally {
      _running = false;
    }
  }

  Future<int> _push(Uri base, String key, String client) async {
    final db = await DatabaseService.instance.database;
    final suppressedThrough = int.tryParse(
          await _state(db, 'outbox_suppressed_through') ?? '',
        ) ??
        0;
    final rows = await db.rawQuery(
        'SELECT o.* FROM corporate_sync_outbox o INNER JOIN '
        '(SELECT entity,record_id,MAX(id) max_id FROM corporate_sync_outbox '
        'WHERE id>? GROUP BY entity,record_id)x ON x.max_id=o.id '
        'ORDER BY o.id LIMIT 200',
        [suppressedThrough]);
    if (rows.isEmpty) return 0;
    final records = <Map<String, Object?>>[], pending = <String, int>{};
    for (final row in rows) {
      final qid = row['id'] as int,
          table = row['entity'].toString(),
          id = row['record_id'].toString();
      if (!entities.contains(table) || id.isEmpty) {
        throw const FormatException('Fila inválida.');
      }
      var deleted = row['operation'] == 'DELETE';
      Map<String, Object?> payload = {'id': id};
      if (!deleted) {
        final Map<String, dynamic>? found =
            await _repository.findById(table, id);
        if (found == null) {
          deleted = true;
        } else {
          final Map<String, Object?> material =
              Map<String, Object?>.from(found);
          if (table == 'laudos' &&
              found['status']?.toString().toUpperCase() == 'LIBERADO') {
            final String path = found['arquivoPath']?.toString().trim() ?? '';
            if (path.isNotEmpty) {
              final File report = File(path);
              if (!await report.exists()) {
                throw StateError('PDF liberado não encontrado: $path');
              }
              final int size = await report.length();
              if (size <= 0 || size > 15 * 1024 * 1024) {
                throw StateError('PDF liberado fora do limite de 15 MB.');
              }
              final List<int> bytes = await report.readAsBytes();
              if (bytes.length < 5 ||
                  utf8.decode(bytes.sublist(0, 5)) != '%PDF-') {
                throw const FormatException(
                    'Arquivo do laudo não é PDF válido.');
              }
              material['pdfBase64'] = base64Encode(bytes);
              material['pdfSha256'] = sha256.convert(bytes).toString();
            }
          }
          payload = await CorporatePayloadCryptoService.instance.seal(
            recordId: id,
            payload: material,
            apiKey: key,
          );
        }
      }
      final operation = '$client:$qid';
      pending[operation] = qid;
      records.add({
        'operation_id': operation,
        'entity': table,
        'record_id': id,
        'payload': payload,
        'deleted': deleted,
        'client_updated_at': row['created_at']
      });
    }
    final answer = await _http(base, '/api/server/sync/push', key,
        method: 'POST', body: {'client_id': client, 'records': records});
    final versions = answer['versions'];
    if (versions is! List) {
      throw const FormatException('Confirmações ausentes.');
    }
    final confirmed = <int>[];
    for (final raw in versions) {
      if (raw is Map) {
        final id = pending[raw['operation_id']?.toString()];
        if (id != null) confirmed.add(id);
      }
    }
    if (confirmed.isNotEmpty) {
      await db.transaction((txn) async {
        for (final row in rows) {
          final queueId = row['id'] as int;
          if (!confirmed.contains(queueId)) continue;
          await txn.delete('corporate_sync_outbox',
              where: 'entity=? AND record_id=? AND id<=?',
              whereArgs: [row['entity'], row['record_id'], queueId]);
        }
      });
    }
    return confirmed.length;
  }

  Future<_CorporatePullResult> _pull(
      Uri base, String key, String client) async {
    final db = await DatabaseService.instance.database;
    var version = int.tryParse(await _state(db, 'server_version') ?? '') ?? 0,
        total = 0;
    var hasMore = false;
    for (var page = 0; page < 20; page++) {
      final answer = await _http(base, '/api/server/sync/pull', key, query: {
        'client_id': client,
        'since_version': '$version',
        'limit': '500'
      });
      final records = answer['records'];
      if (records is! List) throw const FormatException('Alterações ausentes.');
      hasMore = answer['has_more'] == true;
      if (hasMore && records.isEmpty) {
        throw const FormatException(
            'Servidor informou continuação sem retornar registros.');
      }
      await db.transaction((txn) async {
        await _set(txn, 'applying_remote', '1');
        try {
          for (final raw in records) {
            if (raw is! Map) throw const FormatException('Registro inválido.');
            await _apply(txn, Map<String, dynamic>.from(raw), key);
          }
          version =
              int.tryParse(answer['next_version']?.toString() ?? '') ?? version;
          await _set(txn, 'server_version', '$version');
        } finally {
          await _set(txn, 'applying_remote', '0');
        }
      });
      total += records.length;
      if (!hasMore || records.isEmpty) break;
    }
    return _CorporatePullResult(total: total, hasMore: hasMore);
  }

  Future<void> _apply(
    Transaction txn,
    Map<String, dynamic> row,
    String apiKey,
  ) async {
    final table = row['entity']?.toString() ?? '',
        id = row['record_id']?.toString() ?? '',
        raw = row['payload'];
    if (!entities.contains(table) || id.isEmpty || raw is! Map) {
      throw const FormatException('Registro não autorizado.');
    }
    final payload = Map<String, Object?>.from(raw);
    if (payload['id']?.toString() != id) {
      throw const FormatException('ID divergente.');
    }
    final deleted = row['deleted'] == true,
        material = '$table\n$id\n${deleted ? 1 : 0}\n${_canonical(payload)}';
    if (sha256.convert(utf8.encode(material)).toString() != row['sha256']) {
      throw const FormatException('Hash inválido.');
    }
    final Map<String, Object?> opened =
        await CorporatePayloadCryptoService.instance.open(
      recordId: id,
      payload: payload,
      apiKey: apiKey,
    );
    final Map<String, dynamic> encrypted =
        await KristalCryptoService.instance.encryptSensitiveFields(
      Map<String, dynamic>.from(opened),
    );
    final info = await txn.rawQuery('PRAGMA table_info($table)');
    final columns = info.map((e) => e['name'].toString()).toSet();
    final data = <String, Object?>{
      for (final e in encrypted.entries)
        if (columns.contains(e.key)) e.key: e.value
    };
    data['id'] = id;
    if (deleted) {
      final existing = await txn.query(table,
          columns: ['id'], where: 'id=?', whereArgs: [id], limit: 1);
      if (existing.isEmpty) return;
      final tombstone = <String, Object?>{};
      if (columns.contains('arquivado')) tombstone['arquivado'] = '1';
      if (columns.contains('ativoConsultaRecente')) {
        tombstone['ativoConsultaRecente'] = '0';
      }
      if (columns.contains('ativo_consulta_recente')) {
        tombstone['ativo_consulta_recente'] = '0';
      }
      if (columns.contains('ativo')) tombstone['ativo'] = '0';
      if (columns.contains('status')) tombstone['status'] = 'INATIVO';
      if (tombstone.isNotEmpty) {
        await txn.update(table, tombstone, where: 'id=?', whereArgs: [id]);
      }
      return;
    }
    await txn.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> _http(Uri base, String path, String key,
      {String method = 'GET',
      Map<String, String>? query,
      Map<String, Object?>? body}) async {
    final root = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final uri = base.replace(path: '$root$path', queryParameters: query);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request =
          await client.openUrl(method, uri).timeout(const Duration(seconds: 8));
      request.headers.set('X-API-Key', key);
      request.headers.contentType = ContentType.json;
      if (body != null) request.add(utf8.encode(jsonEncode(body)));
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}: $text', uri: uri);
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) throw const FormatException('JSON não é objeto.');
      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _client() async {
    final db = await DatabaseService.instance.database,
        saved = await _state(db, 'client_id');
    if (saved != null && saved.isNotEmpty) return saved;
    final random = Random.secure();
    final id =
        'HMR-${base64UrlEncode(List.generate(18, (_) => random.nextInt(256))).replaceAll('=', '')}';
    await _set(db, 'client_id', id);
    return id;
  }

  Future<String?> _state(Database db, String key) async {
    final rows = await db.query('corporate_sync_state',
        columns: ['value'], where: 'key=?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  Future<int> _initialPullOutboxWatermark(Database db) async {
    final saved = int.tryParse(
      await _state(db, 'initial_pull_outbox_watermark') ?? '',
    );
    if (saved != null && saved >= 0) return saved;
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(id),0) AS max_id FROM corporate_sync_outbox',
    );
    final watermark = (rows.first['max_id'] as num?)?.toInt() ?? 0;
    await _set(db, 'initial_pull_outbox_watermark', '$watermark');
    return watermark;
  }

  Future<void> _set(DatabaseExecutor db, String key, String value) =>
      db.insert('corporate_sync_state', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
  Future<bool> _exists(DatabaseExecutor db, String table) async =>
      (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [table]))
          .isNotEmpty;
  Uri _base(ServerConfig c) {
    final uri = Uri.tryParse(c.localServerUrl.trim());
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) return uri;
    return Uri(
        scheme: 'https',
        host: c.servidorLocalHost,
        port: int.tryParse(c.servidorLocalPorta) ?? 8787);
  }

  String _canonical(Object? value) => jsonEncode(_sort(value));
  Object? _sort(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      return {for (final key in keys) key: _sort(value[key])};
    }
    if (value is List) return value.map(_sort).toList();
    return value;
  }
}
