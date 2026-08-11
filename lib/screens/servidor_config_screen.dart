import 'dart:io';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/server_config_service.dart';
import '../services/server_connection_service.dart';
import '../services/server_sync_service.dart';
import '../services/log_service.dart';
import '../services/windows_data_protection_service.dart';

class ServidorConfigScreen extends StatefulWidget {
  final AuthSession session;

  const ServidorConfigScreen({
    super.key,
    required this.session,
  });

  @override
  State<ServidorConfigScreen> createState() => _ServidorConfigScreenState();
}

class _ServidorConfigScreenState extends State<ServidorConfigScreen> {
  final TextEditingController bancoLocalPath = TextEditingController();
  final TextEditingController backupLocalPath = TextEditingController();
  final TextEditingController localHost = TextEditingController();
  final TextEditingController localPorta = TextEditingController();
  final TextEditingController nuvemBaseUrl = TextEditingController();
  final TextEditingController nuvemApiKey = TextEditingController();
  final TextEditingController intervalo = TextEditingController();
  final TextEditingController observacao = TextEditingController();

  String modo = 'LOCAL';
  bool usarCriptografia = true;
  bool sincronizacaoAtiva = false;
  bool loading = true;
  String status = 'Carregando configurações do servidor...';

  bool get canEdit => widget.session.isSuperUser;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    bancoLocalPath.dispose();
    backupLocalPath.dispose();
    localHost.dispose();
    localPorta.dispose();
    nuvemBaseUrl.dispose();
    nuvemApiKey.dispose();
    intervalo.dispose();
    observacao.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final ServerConfig config = await ServerConfigService.instance.carregar();

    if (!mounted) return;

    setState(() {
      modo = config.modo;
      bancoLocalPath.text = config.bancoLocalPath;
      backupLocalPath.text = config.backupLocalPath;
      localHost.text = config.servidorLocalHost;
      localPorta.text = config.servidorLocalPorta;
      nuvemBaseUrl.text = config.nuvemBaseUrl;
      nuvemApiKey.text = config.nuvemApiKey;
      usarCriptografia = config.usarCriptografia == '1';
      sincronizacaoAtiva = config.sincronizacaoAtiva == '1';
      intervalo.text = config.intervaloMinutos;
      observacao.text = config.observacao;
      status = config.ultimaSincronizacao.isEmpty
          ? 'Configure o apontamento local, nuvem ou híbrido.'
          : 'Última sincronização: ${config.ultimaSincronizacao}';
      loading = false;
    });
  }

  ServerConfig _configAtual() {
    return ServerConfig(
      modo: modo,
      bancoLocalPath: bancoLocalPath.text.trim(),
      backupLocalPath: backupLocalPath.text.trim(),
      servidorLocalHost: localHost.text.trim(),
      servidorLocalPorta: localPorta.text.trim(),
      nuvemBaseUrl: nuvemBaseUrl.text.trim(),
      nuvemApiKey: nuvemApiKey.text.trim(),
      usarCriptografia: usarCriptografia ? '1' : '0',
      sincronizacaoAtiva: sincronizacaoAtiva ? '1' : '0',
      intervaloMinutos:
          intervalo.text.trim().isEmpty ? '15' : intervalo.text.trim(),
      ultimaSincronizacao: '',
      observacao: observacao.text.trim(),
    );
  }

  Future<void> _salvar() async {
    try {
      await ServerConfigService.instance.salvar(
        session: widget.session,
        config: _configAtual(),
      );

      if (!mounted) return;

      setState(() => status = 'Configuração do servidor salva.');
    } on FileSystemException catch (e, stackTrace) {
      await LogService.instance.error('SERVER_CONFIG_FILE', e, stackTrace);
      if (!mounted) return;
      setState(() => status = 'Erro ao salvar: $e');
    } on WindowsDataProtectionException catch (e, stackTrace) {
      await LogService.instance.error('SERVER_CONFIG_DPAPI', e, stackTrace);
      if (!mounted) return;
      setState(() => status = 'Erro ao salvar: $e');
    }
  }

  Future<void> _testarLocal() async {
    final ServerConnectionResult result =
        await ServerConnectionService.instance.testarLocal(_configAtual());

    if (!mounted) return;

    setState(() => status = result.message);
  }

  Future<void> _testarNuvem() async {
    final ServerConnectionResult result =
        await ServerConnectionService.instance.testarNuvem(_configAtual());

    if (!mounted) return;

    setState(() => status = result.message);
  }

  Future<void> _snapshotLocal() async {
    final ServerConnectionResult result =
        await ServerConnectionService.instance.exportarSnapshotLocal(
      usuario: widget.session.login,
      config: _configAtual(),
    );

    if (!mounted) return;

    setState(() => status = result.message);
  }

  Future<void> _sincronizarAgora() async {
    final String result = await ServerSyncService.instance.sincronizarAgora(
      usuario: widget.session.login,
    );

    if (!mounted) return;

    setState(() => status = result);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: canEdit,
      obscureText: obscure,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool mostrarLocal = modo == 'LOCAL' || modo == 'HIBRIDO';
    final bool mostrarNuvem = modo == 'NUVEM' || modo == 'HIBRIDO';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servidor Local / Nuvem'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Recarregar',
            onPressed: _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.dns),
                    title: const Text('Apontamento do Servidor'),
                    subtitle: Text(
                      canEdit
                          ? 'Local, nuvem ou híbrido. Alteração exclusiva do Superusuário.'
                          : 'Somente o Superusuário pode alterar esta área.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: modo,
                  decoration: const InputDecoration(
                    labelText: 'Modo de operação',
                    prefixIcon: Icon(Icons.hub),
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'LOCAL',
                      child: Text('LOCAL'),
                    ),
                    DropdownMenuItem(
                      value: 'NUVEM',
                      child: Text('NUVEM'),
                    ),
                    DropdownMenuItem(
                      value: 'HIBRIDO',
                      child: Text('HÍBRIDO'),
                    ),
                  ],
                  onChanged: canEdit
                      ? (String? value) {
                          if (value == null) return;
                          setState(() => modo = value);
                        }
                      : null,
                ),
                const SizedBox(height: 18),
                if (mostrarLocal) ...<Widget>[
                  const _SectionTitle(
                    icon: Icons.computer,
                    title: 'Servidor Local / Rede',
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: bancoLocalPath,
                    label: r'Caminho do banco local/rede',
                    icon: Icons.storage,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: backupLocalPath,
                    label: r'Pasta de backup/sincronização local',
                    icon: Icons.folder_copy,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _field(
                          controller: localHost,
                          label: 'Host/IP local',
                          icon: Icons.router,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 180,
                        child: _field(
                          controller: localPorta,
                          label: 'Porta',
                          icon: Icons.settings_ethernet,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testarLocal,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Testar local'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _snapshotLocal,
                    icon: const Icon(Icons.enhanced_encryption),
                    label: const Text('Gerar snapshot local criptografado'),
                  ),
                  const SizedBox(height: 18),
                ],
                if (mostrarNuvem) ...<Widget>[
                  const _SectionTitle(
                    icon: Icons.cloud,
                    title: 'Servidor em Nuvem',
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: nuvemBaseUrl,
                    label: 'URL base da API/nuvem',
                    icon: Icons.language,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: nuvemApiKey,
                    label: 'Token/API Key',
                    icon: Icons.key,
                    obscure: true,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testarNuvem,
                    icon: const Icon(Icons.cloud_done),
                    label: const Text('Testar nuvem'),
                  ),
                  const SizedBox(height: 18),
                ],
                SwitchListTile(
                  title: const Text('Criptografia ativa'),
                  subtitle: const Text('Mantém backups/snapshots protegidos.'),
                  value: usarCriptografia,
                  onChanged: canEdit
                      ? (bool value) {
                          setState(() => usarCriptografia = value);
                        }
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Sincronização automática'),
                  subtitle: const Text(
                    'Executa sync conforme intervalo configurado.',
                  ),
                  value: sincronizacaoAtiva,
                  onChanged: canEdit
                      ? (bool value) {
                          setState(() => sincronizacaoAtiva = value);
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: intervalo,
                  label: 'Intervalo de sincronização em minutos',
                  icon: Icons.timer,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: observacao,
                  label: 'Observação técnica',
                  icon: Icons.notes,
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    ElevatedButton.icon(
                      onPressed: canEdit ? _salvar : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar servidor'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _sincronizarAgora,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sincronizar agora'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      status,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
