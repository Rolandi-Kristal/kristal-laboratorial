import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../services/server_config_service.dart';

class ServidorNuvemScreen extends StatefulWidget {
  const ServidorNuvemScreen({super.key});

  @override
  State<ServidorNuvemScreen> createState() => _ServidorNuvemScreenState();
}

class _ServidorNuvemScreenState extends State<ServidorNuvemScreen> {
  final ServerConfigService _service = ServerConfigService.instance;

  final TextEditingController _localUrlController = TextEditingController();
  final TextEditingController _cloudUrlController = TextEditingController();
  final TextEditingController _portalUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _sirePathController = TextEditingController();
  final TextEditingController _sireExternalPathController =
      TextEditingController();

  String _mode = 'LOCAL';
  bool _syncEnabled = true;
  bool _loading = true;
  String _status = 'Carregando configurações...';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _localUrlController.dispose();
    _cloudUrlController.dispose();
    _portalUrlController.dispose();
    _apiKeyController.dispose();
    _sirePathController.dispose();
    _sireExternalPathController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
    });

    try {
      final ServerConfig config = await _service.carregar();

      if (!mounted) {
        return;
      }

      setState(() {
        _mode = config.modo.isEmpty ? 'LOCAL' : config.modo;
        _localUrlController.text = config.localServerUrl.isNotEmpty
            ? config.localServerUrl
            : 'http://${config.servidorLocalHost}:${config.servidorLocalPorta}';
        _cloudUrlController.text = config.cloudServerUrl.isNotEmpty
            ? config.cloudServerUrl
            : config.nuvemBaseUrl;
        _portalUrlController.text = config.portalUrl.isNotEmpty
            ? config.portalUrl
            : AppConstants.portalPacienteUrl;
        _apiKeyController.text = config.nuvemApiKey.isNotEmpty
            ? config.nuvemApiKey
            : config.cloudApiToken;
        _sirePathController.text = config.sirePath.isNotEmpty
            ? config.sirePath
            : AppConstants.kristalSireShortcutPath;
        _sireExternalPathController.text = config.sireExternalPath.isNotEmpty
            ? config.sireExternalPath
            : AppConstants.kristalSireExternalShortcutPath;
        _syncEnabled = config.sincronizacaoAtiva == '1' ||
            config.syncEnabled == '1' ||
            config.sincronizacaoAtiva.toLowerCase() == 'true';
        _status = 'Configurações carregadas.';
      });
    } on FileSystemException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Erro de arquivo: ${error.message}';
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Configuração inválida: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<ServerConfig> _currentConfig() async {
    return _service.carregar();
  }

  Future<void> _saveLocalServer() async {
    final ServerConfig current = await _currentConfig();
    final String localUrl = _localUrlController.text.trim();

    if (!_isValidHttpUrl(localUrl)) {
      setState(() {
        _status = 'Servidor local inválido. Use http://IP:PORTA ou https://IP.';
      });
      return;
    }

    final Uri uri = Uri.parse(localUrl);

    await _service.salvar(
      config: current.copyWith(
        modo: _mode,
        connectionMode: _mode,
        localServerUrl: localUrl,
        servidorLocalHost: uri.host,
        servidorLocalPorta: uri.hasPort ? uri.port.toString() : '80',
      ),
    );

    setState(() {
      _status = 'Servidor local salvo em rota própria.';
    });
  }

  Future<void> _saveCloudServer() async {
    final ServerConfig current = await _currentConfig();
    final String cloudUrl = _cloudUrlController.text.trim();

    if (cloudUrl.isNotEmpty && !_isValidHttpUrl(cloudUrl)) {
      setState(() {
        _status = 'Servidor em nuvem inválido. Use http:// ou https://.';
      });
      return;
    }

    await _service.salvar(
      config: current.copyWith(
        modo: _mode,
        connectionMode: _mode,
        cloudServerUrl: cloudUrl,
        cloudBaseUrl: cloudUrl,
        nuvemBaseUrl: cloudUrl,
      ),
    );

    setState(() {
      _status = 'Servidor em nuvem salvo em rota própria.';
    });
  }

  Future<void> _savePatientPortal() async {
    final ServerConfig current = await _currentConfig();
    final String portalUrl = _portalUrlController.text.trim();

    if (!_isValidHttpUrl(portalUrl)) {
      setState(() {
        _status = 'Portal do paciente inválido. Use http:// ou https://.';
      });
      return;
    }

    await _service.salvar(config: current.copyWith(portalUrl: portalUrl));

    setState(() {
      _status = 'Portal do paciente salvo em rota própria.';
    });
  }

  Future<void> _saveApiKey() async {
    final ServerConfig current = await _currentConfig();
    final String apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      setState(() {
        _status = 'Informe a chave API gerada no servidor de produção.';
      });
      return;
    }

    await _service.salvar(
      config: current.copyWith(
        nuvemApiKey: apiKey,
        cloudApiToken: apiKey,
      ),
    );

    setState(() {
      _status = 'Chave API salva localmente para comunicação protegida.';
    });
  }

  Future<void> _testProtectedServerStatus() async {
    await _callProtectedServer(
      method: 'GET',
      path: '/api/server/status',
      successLabel: 'Status protegido do servidor',
    );
  }

  Future<void> _backupManualServidor() async {
    await _callProtectedServer(
      method: 'POST',
      path: '/api/server/backup',
      successLabel: 'Backup manual do servidor',
    );
  }

  Future<void> _callProtectedServer({
    required String method,
    required String path,
    required String successLabel,
  }) async {
    final String apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _status =
            'Informe a chave API do servidor antes de executar a operação.';
      });
      return;
    }

    final String baseUrl = _localUrlController.text.trim();
    if (!_isValidHttpUrl(baseUrl)) {
      setState(() {
        _status = 'URL do servidor local inválida.';
      });
      return;
    }

    final Uri base = Uri.parse(baseUrl);
    final Uri uri = base.replace(path: _joinUriPath(base.path, path));
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);

    try {
      final HttpClientRequest request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 12));
      request.headers.set('X-API-Key', apiKey);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 30));
      final String body = await response.transform(const Utf8Decoder()).join();

      setState(() {
        _status = '$successLabel: HTTP ${response.statusCode}. $body';
      });
    } on SocketException {
      setState(() {
        _status = 'Servidor não respondeu na rota protegida.';
      });
    } on HttpException catch (error) {
      setState(() {
        _status = 'Erro HTTP na rota protegida: ${error.message}';
      });
    } on FormatException catch (error) {
      setState(() {
        _status = 'Resposta inválida do servidor: ${error.message}';
      });
    } finally {
      client.close(force: true);
    }
  }

  String _joinUriPath(String basePath, String path) {
    final String cleanBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final String cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  Future<void> _saveSireRoutes() async {
    final ServerConfig current = await _currentConfig();
    final String sirePath = _sirePathController.text.trim();
    final String sireExternalPath = _sireExternalPathController.text.trim();

    if (sirePath.isEmpty || sireExternalPath.isEmpty) {
      setState(() {
        _status = 'Informe os dois atalhos do KRISTAL SIRE.';
      });
      return;
    }

    await _service.salvar(
      config: current.copyWith(
        sirePath: sirePath,
        sireExternalPath: sireExternalPath,
      ),
    );

    setState(() {
      _status = 'Rotas KRISTAL SIRE salvas separadamente do servidor.';
    });
  }

  Future<void> _saveSync() async {
    final ServerConfig current = await _currentConfig();

    await _service.salvar(
      config: current.copyWith(
        syncEnabled: _syncEnabled ? '1' : '0',
        sincronizacaoAtiva: _syncEnabled ? '1' : '0',
      ),
    );

    setState(() {
      _status = 'Sincronização salva.';
    });
  }

  Future<void> _testLocalServer() async {
    await _testUrl(
        url: _localUrlController.text.trim(), label: 'servidor local');
  }

  Future<void> _testCloudServer() async {
    final String url = _cloudUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _status = 'Servidor em nuvem ainda não informado.';
      });
      return;
    }
    await _testUrl(url: url, label: 'servidor em nuvem');
  }

  Future<void> _testPatientPortal() async {
    await _testUrl(
        url: _portalUrlController.text.trim(), label: 'portal do paciente');
  }

  Future<void> _testSireRoutes() async {
    final bool sireExists =
        await File(_sirePathController.text.trim()).exists();
    final bool sireExternalExists =
        await File(_sireExternalPathController.text.trim()).exists();

    setState(() {
      _status =
          'KRISTAL SIRE: principal ${sireExists ? "OK" : "não encontrado"}; '
          'externos ${sireExternalExists ? "OK" : "não encontrado"}.';
    });
  }

  Future<void> _testUrl({required String url, required String label}) async {
    if (!_isValidHttpUrl(url)) {
      setState(() {
        _status = 'URL do $label inválida.';
      });
      return;
    }

    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      final HttpClientRequest request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 4));
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 4));

      setState(() {
        _status = 'Teste do $label concluído. HTTP ${response.statusCode}.';
      });
    } on SocketException {
      setState(() {
        _status = 'Não foi possível conectar ao $label.';
      });
    } on HttpException catch (error) {
      setState(() {
        _status = 'Erro HTTP no $label: ${error.message}';
      });
    } on TlsException catch (error) {
      setState(() {
        _status = 'Erro TLS no $label: ${error.message}';
      });
    } finally {
      client.close(force: true);
    }
  }

  bool _isValidHttpUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          _Header(
            title: 'Servidor / Nuvem',
            subtitle:
                'Configurações separadas para servidor local, nuvem, portal e KRISTAL SIRE',
            icon: Icons.cloud_sync_rounded,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: <Widget>[
                        _modePanel(),
                        const SizedBox(height: 14),
                        _routePanel(
                          title: 'Servidor local',
                          subtitle:
                              'Rota própria para o servidor da rede interna.',
                          controller: _localUrlController,
                          icon: Icons.dns_rounded,
                          onSave: _saveLocalServer,
                          onTest: _testLocalServer,
                        ),
                        const SizedBox(height: 14),
                        _routePanel(
                          title: 'Servidor em nuvem',
                          subtitle:
                              'Rota própria para servidor externo ou hospedagem.',
                          controller: _cloudUrlController,
                          icon: Icons.cloud_rounded,
                          onSave: _saveCloudServer,
                          onTest: _testCloudServer,
                        ),
                        const SizedBox(height: 14),
                        _routePanel(
                          title: 'Portal do paciente',
                          subtitle:
                              'Rota própria para acesso, consulta, impressão e download de laudos.',
                          controller: _portalUrlController,
                          icon: Icons.public_rounded,
                          onSave: _savePatientPortal,
                          onTest: _testPatientPortal,
                        ),
                        const SizedBox(height: 14),
                        _backupPanel(),
                        const SizedBox(height: 14),
                        _sirePanel(),
                        const SizedBox(height: 14),
                        _syncPanel(),
                      ],
                    ),
                  ),
          ),
          _Footer(status: _status),
        ],
      ),
    );
  }

  Widget _modePanel() => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Modo de conexão',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, children: <Widget>[
              _modeButton('LOCAL', 'Local'),
              _modeButton('NUVEM', 'Nuvem'),
              _modeButton('HIBRIDO', 'Híbrido'),
            ]),
          ],
        ),
      );

  Widget _modeButton(String value, String label) => ChoiceChip(
        selected: _mode == value,
        label: Text(label),
        onSelected: (bool selected) {
          if (selected) setState(() => _mode = value);
        },
      );

  Widget _routePanel({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required IconData icon,
    required Future<void> Function() onSave,
    required Future<void> Function() onTest,
  }) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _panelTitle(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: title,
              prefixIcon: Icon(icon),
              filled: true,
              fillColor: const Color(0xFF071827),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: <Widget>[
            ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded),
                label: Text('Salvar $title')),
            const SizedBox(width: 10),
            OutlinedButton.icon(
                onPressed: onTest,
                icon: const Icon(Icons.network_check_rounded),
                label: const Text('Testar conexão')),
          ]),
        ],
      ),
    );
  }

  Widget _backupPanel() => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _panelTitle(
              title: 'Backup do servidor',
              subtitle:
                  'Backup manual real via API protegida. O automático é instalado no Windows do servidor.',
              icon: Icons.backup_rounded,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Chave API do servidor',
                prefixIcon: Icon(Icons.key_rounded),
                filled: true,
                fillColor: Color(0xFF071827),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
              ElevatedButton.icon(
                  onPressed: _saveApiKey,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Salvar chave API')),
              OutlinedButton.icon(
                  onPressed: _testProtectedServerStatus,
                  icon: const Icon(Icons.verified_user_rounded),
                  label: const Text('Testar status protegido')),
              ElevatedButton.icon(
                  onPressed: _backupManualServidor,
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('Backup manual do servidor')),
            ]),
          ],
        ),
      );

  Widget _sirePanel() => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _panelTitle(
              title: 'KRISTAL SIRE',
              subtitle:
                  'Rotas separadas do servidor. Usadas apenas para faturamento e exportação SIRE.',
              icon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sirePathController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Atalho KRISTAL_SIRE.lnk',
                  prefixIcon: Icon(Icons.shortcut_rounded),
                  filled: true,
                  fillColor: Color(0xFF071827),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sireExternalPathController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Atalho KRISTAL_SIRE_EXTERNOS.lnk',
                  prefixIcon: Icon(Icons.shortcut_rounded),
                  filled: true,
                  fillColor: Color(0xFF071827),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(children: <Widget>[
              ElevatedButton.icon(
                  onPressed: _saveSireRoutes,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Salvar rotas SIRE')),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                  onPressed: _testSireRoutes,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Verificar arquivos')),
            ]),
          ],
        ),
      );

  Widget _syncPanel() => _Panel(
        child: Row(
          children: <Widget>[
            const Icon(Icons.sync_rounded, color: Color(0xFF73D7FF)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Sincronização habilitada',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900))),
            Switch(
                value: _syncEnabled,
                onChanged: (bool value) =>
                    setState(() => _syncEnabled = value)),
            const SizedBox(width: 12),
            ElevatedButton.icon(
                onPressed: _saveSync,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Salvar sincronização')),
          ],
        ),
      );

  Widget _panelTitle(
          {required String title,
          required String subtitle,
          required IconData icon}) =>
      Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF73D7FF), size: 26),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFFB7D7F1), fontWeight: FontWeight.w600)),
              ])),
        ],
      );
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
            color: Color(0xFF18344F),
            border: Border(bottom: BorderSide(color: Color(0xFF26577D)))),
        child: Row(children: <Widget>[
          Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: const Color(0xFF0E88C6).withOpacity(0.24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3EC6FF))),
              child: Icon(icon, color: const Color(0xFF73D7FF), size: 30)),
          const SizedBox(width: 18),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFFB7D7F1), fontWeight: FontWeight.w700)),
              ])),
          Image.asset(AppConstants.hmrLogoPath,
              width: 52,
              height: 52,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.local_hospital_rounded,
                  color: Color(0xFF73D7FF),
                  size: 42)),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0xFF0D2033),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF244B6D))),
      child: child);
}

class _Footer extends StatelessWidget {
  const _Footer({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: const Color(0xFF06111D),
      child: Text(status,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFFFFC857), fontWeight: FontWeight.w800)));
}
