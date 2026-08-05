import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_service.dart';
import 'server_config_service.dart';

class CorporateSyncResult {
  const CorporateSyncResult(this.ok, this.message,
      {this.pushed = 0, this.pulled = 0});
  final bool ok;
  final String message;
  final int pushed;
  final int pulled;
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
    'equipment_connections'
  ];
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
      final pushed = await _push(base, key, client),
          pulled = await _pull(base, key, client);
      return CorporateSyncResult(true, 'Sincronização concluída.',
          pushed: pushed, pulled: pulled);
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
    final rows = await db.rawQuery(
        'SELECT o.* FROM corporate_sync_outbox o INNER JOIN '
        '(SELECT entity,record_id,MAX(id) max_id FROM corporate_sync_outbox GROUP BY '
        'entity,record_id)x ON x.max_id=o.id ORDER BY o.id LIMIT 200');
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
        final found =
            await db.query(table, where: 'id=?', whereArgs: [id], limit: 1);
        if (found.isEmpty) {
          deleted = true;
        } else {
          payload = Map.from(found.first);
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

  Future<int> _pull(Uri base, String key, String client) async {
    final db = await DatabaseService.instance.database;
    var version = int.tryParse(await _state(db, 'server_version') ?? '') ?? 0,
        total = 0;
    for (var page = 0; page < 20; page++) {
      final answer = await _http(base, '/api/server/sync/pull', key, query: {
        'client_id': client,
        'since_version': '$version',
        'limit': '500'
      });
      final records = answer['records'];
      if (records is! List) throw const FormatException('Alterações ausentes.');
      await db.transaction((txn) async {
        await _set(txn, 'applying_remote', '1');
        try {
          for (final raw in records) {
            if (raw is! Map) throw const FormatException('Registro inválido.');
            await _apply(txn, Map<String, dynamic>.from(raw));
          }
          version =
              int.tryParse(answer['next_version']?.toString() ?? '') ?? version;
          await _set(txn, 'server_version', '$version');
        } finally {
          await _set(txn, 'applying_remote', '0');
        }
      });
      total += records.length;
      if (answer['has_more'] != true || records.isEmpty) break;
    }
    return total;
  }

  Future<void> _apply(Transaction txn, Map<String, dynamic> row) async {
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
    final info = await txn.rawQuery('PRAGMA table_info($table)');
    final columns = info.map((e) => e['name'].toString()).toSet();
    final data = <String, Object?>{
      for (final e in payload.entries)
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
        scheme: 'http',
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
