import 'dart:io';

import 'package:path/path.dart' as p;

class PortalWebRuntimeService {
  PortalWebRuntimeService._();

  static final PortalWebRuntimeService instance = PortalWebRuntimeService._();

  Process? _process;

  String get portalDir => p.join(Directory.current.path, 'portal_web');
  String get mainPath => p.join(portalDir, 'main.py');
  String get urlPaciente => 'http://127.0.0.1:8787';
  String get urlAdmin => 'http://127.0.0.1:8787/admin.html';

  bool get isRunning => _process != null;

  Future<bool> instalado() async {
    return File(mainPath).exists();
  }

  Future<String> start() async {
    if (_process != null) return 'Portal web ja esta iniciado.';
    if (!await instalado()) {
      return 'Portal web nao encontrado em $portalDir.';
    }

    _process = await Process.start(
      'python',
      <String>[mainPath],
      workingDirectory: portalDir,
      mode: ProcessStartMode.detachedWithStdio,
    );

    return 'Portal web iniciado em $urlPaciente e $urlAdmin.';
  }

  Future<String> stop() async {
    final Process? process = _process;
    if (process == null) return 'Portal web nao estava iniciado por este app.';
    process.kill();
    _process = null;
    return 'Portal web parado.';
  }

  Future<String> health() async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(
        Uri.parse('$urlPaciente/health'),
      );
      final HttpClientResponse response = await request.close();
      if (response.statusCode == 200) {
        return 'Portal web respondendo em /health.';
      }
      return 'Portal web respondeu HTTP ${response.statusCode}.';
    } catch (e) {
      return 'Portal web nao respondeu: $e';
    } finally {
      client.close(force: true);
    }
  }
}
