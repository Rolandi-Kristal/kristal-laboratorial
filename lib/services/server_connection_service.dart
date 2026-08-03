import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'database_export_snapshot_service.dart';
import 'server_config_service.dart';

class ServerConnectionResult {
  final bool ok;
  final String message;

  const ServerConnectionResult({
    required this.ok,
    required this.message,
  });
}

class ServerConnectionService {
  ServerConnectionService._();

  static final ServerConnectionService instance = ServerConnectionService._();

  Future<ServerConnectionResult> testarLocal(ServerConfig config) async {
    final List<String> checks = <String>[];

    if (config.bancoLocalPath.trim().isNotEmpty) {
      final File dbFile = File(config.bancoLocalPath.trim());
      final Directory dbDir = dbFile.parent;

      if (!await dbDir.exists()) {
        return ServerConnectionResult(
          ok: false,
          message: 'Pasta do banco local não existe: ${dbDir.path}',
        );
      }

      checks.add('Pasta do banco local OK: ${dbDir.path}');
    }

    if (config.backupLocalPath.trim().isNotEmpty) {
      final Directory backupDir = Directory(config.backupLocalPath.trim());

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      checks.add('Pasta de backup/sincronização OK: ${backupDir.path}');
    }

    final String host = config.servidorLocalHost.trim();
    final int? port = int.tryParse(config.servidorLocalPorta.trim());

    if (host.isNotEmpty && port != null) {
      try {
        final Socket socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 3),
        );

        await socket.close();
        checks.add('Servidor local respondeu em $host:$port');
      } catch (_) {
        checks.add(
          'Host/porta configurados, mas sem resposta no teste: $host:$port',
        );
      }
    }

    if (checks.isEmpty) {
      return const ServerConnectionResult(
        ok: false,
        message: 'Nenhuma configuração local informada.',
      );
    }

    return ServerConnectionResult(
      ok: true,
      message: checks.join('\n'),
    );
  }

  Future<ServerConnectionResult> testarNuvem(ServerConfig config) async {
    final Uri? baseUri = Uri.tryParse(config.nuvemBaseUrl.trim());

    if (baseUri == null || !baseUri.hasScheme || !baseUri.hasAuthority) {
      return const ServerConnectionResult(
        ok: false,
        message: 'URL da nuvem inválida.',
      );
    }

    final Uri healthUri = baseUri.replace(
      path: p.url.join(baseUri.path, 'health'),
    );

    try {
      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);

      final HttpClientRequest request = await client.getUrl(healthUri);

      if (config.nuvemApiKey.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${config.nuvemApiKey.trim()}',
        );
      }

      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      client.close(force: true);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ServerConnectionResult(
          ok: true,
          message: 'Nuvem respondeu HTTP ${response.statusCode}: $body',
        );
      }

      return ServerConnectionResult(
        ok: false,
        message: 'Nuvem respondeu HTTP ${response.statusCode}: $body',
      );
    } catch (e) {
      return ServerConnectionResult(
        ok: false,
        message: 'Falha no teste de nuvem: $e',
      );
    }
  }

  Future<ServerConnectionResult> exportarSnapshotLocal({
    required String usuario,
    required ServerConfig config,
  }) async {
    if (config.backupLocalPath.trim().isEmpty) {
      return const ServerConnectionResult(
        ok: false,
        message: 'Informe a pasta local de backup/sincronização.',
      );
    }

    final Directory backupDir = Directory(config.backupLocalPath.trim());

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final String sourcePath =
        await DatabaseExportSnapshotService.instance.exportarSnapshotCriptografado(
      usuario: usuario,
    );

    final File source = File(sourcePath);
    final File target = File(
      p.join(
        backupDir.path,
        p.basename(source.path),
      ),
    );

    await source.copy(target.path);

    return ServerConnectionResult(
      ok: true,
      message: 'Snapshot criptografado exportado para: ${target.path}',
    );
  }
}