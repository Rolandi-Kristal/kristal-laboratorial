import 'dart:async';
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
      } on SocketException catch (error) {
        checks.add(
          'Servidor local sem resposta em $host:$port: ${error.message}',
        );
      } on TimeoutException catch (error) {
        checks.add(
          'Tempo esgotado ao testar $host:$port: ${error.message ?? error}',
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

    if (baseUri == null || baseUri.scheme != 'https' || !baseUri.hasAuthority) {
      return const ServerConnectionResult(
        ok: false,
        message: 'URL da nuvem inválida.',
      );
    }

    final Uri healthUri = baseUri.replace(
      path: p.url.join(baseUri.path, 'health'),
    );

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final HttpClientRequest request = await client.getUrl(healthUri);
      if (config.nuvemApiKey.trim().isNotEmpty) {
        request.headers.set(
          'X-API-Key',
          config.nuvemApiKey.trim(),
        );
      }
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
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
    } on SocketException catch (error) {
      return ServerConnectionResult(
        ok: false,
        message: 'Falha de rede no teste de nuvem: ${error.message}',
      );
    } on HandshakeException catch (error) {
      return ServerConnectionResult(
        ok: false,
        message: 'Falha TLS no teste de nuvem: ${error.message}',
      );
    } on HttpException catch (error) {
      return ServerConnectionResult(
        ok: false,
        message: 'Falha HTTP no teste de nuvem: ${error.message}',
      );
    } on FormatException catch (error) {
      return ServerConnectionResult(
        ok: false,
        message: 'Resposta inválida da nuvem: ${error.message}',
      );
    } finally {
      client.close(force: true);
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

    final String sourcePath = await DatabaseExportSnapshotService.instance
        .exportarSnapshotCriptografado(
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
