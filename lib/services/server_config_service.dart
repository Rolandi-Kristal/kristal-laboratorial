import 'dart:convert';
import 'dart:io';

import '../core/app_constants.dart';

class ServerConfig {
  const ServerConfig({
    this.modo = 'LOCAL',
    this.localDbPath = AppConstants.bancoLocalPath,
    this.localBackupPath = AppConstants.backupLocalPath,
    this.cloudBaseUrl = '',
    this.cloudApiToken = '',
    this.syncEnabled = '1',
    this.syncIntervalMinutes = '15',
    this.lastSyncAt = '',
    this.observacao = '',
    this.bancoLocalPath = AppConstants.bancoLocalPath,
    this.backupLocalPath = AppConstants.backupLocalPath,
    this.servidorLocalHost = AppConstants.servidorLocalHost,
    this.servidorLocalPorta = AppConstants.servidorLocalPorta,
    this.nuvemBaseUrl = '',
    this.nuvemApiKey = '',
    this.usarCriptografia = '1',
    this.sincronizacaoAtiva = '1',
    this.intervaloMinutos = '15',
    this.ultimaSincronizacao = '',
    this.connectionMode = 'LOCAL',
    this.localServerUrl = AppConstants.portalPacienteUrl,
    this.cloudServerUrl = '',
    this.portalUrl = AppConstants.portalPacienteUrl,
    this.sirePath = AppConstants.kristalSireShortcutPath,
    this.sireExternalPath = AppConstants.kristalSireExternalShortcutPath,
  });

  final String modo;
  final String localDbPath;
  final String localBackupPath;
  final String cloudBaseUrl;
  final String cloudApiToken;
  final String syncEnabled;
  final String syncIntervalMinutes;
  final String lastSyncAt;
  final String observacao;

  final String bancoLocalPath;
  final String backupLocalPath;
  final String servidorLocalHost;
  final String servidorLocalPorta;
  final String nuvemBaseUrl;
  final String nuvemApiKey;
  final String usarCriptografia;
  final String sincronizacaoAtiva;
  final String intervaloMinutos;
  final String ultimaSincronizacao;

  final String connectionMode;
  final String localServerUrl;
  final String cloudServerUrl;
  final String portalUrl;
  final String sirePath;
  final String sireExternalPath;

  bool get isLocal => modo.toUpperCase() == 'LOCAL';
  bool get isCloud => modo.toUpperCase() == 'NUVEM' || modo.toUpperCase() == 'CLOUD';
  bool get isNuvem => isCloud;
  bool get isHybrid => modo.toUpperCase() == 'HIBRIDO' || modo.toUpperCase() == 'HÍBRIDO' || modo.toUpperCase() == 'HYBRID';
  bool get isHibrido => isHybrid;
  bool get syncEnabledBool => syncEnabled == '1' || syncEnabled.toLowerCase() == 'true';
  bool get usarCriptografiaBool =>
      usarCriptografia == '1' || usarCriptografia.toLowerCase() == 'true';
  bool get sincronizacaoAtivaBool =>
      sincronizacaoAtiva == '1' || sincronizacaoAtiva.toLowerCase() == 'true';

  ServerConfig copyWith({
    String? modo,
    String? localDbPath,
    String? localBackupPath,
    String? cloudBaseUrl,
    String? cloudApiToken,
    String? syncEnabled,
    String? syncIntervalMinutes,
    String? lastSyncAt,
    String? observacao,
    String? bancoLocalPath,
    String? backupLocalPath,
    String? servidorLocalHost,
    String? servidorLocalPorta,
    String? nuvemBaseUrl,
    String? nuvemApiKey,
    String? usarCriptografia,
    String? sincronizacaoAtiva,
    String? intervaloMinutos,
    String? ultimaSincronizacao,
    String? connectionMode,
    String? localServerUrl,
    String? cloudServerUrl,
    String? portalUrl,
    String? sirePath,
    String? sireExternalPath,
  }) {
    return ServerConfig(
      modo: modo ?? this.modo,
      localDbPath: localDbPath ?? this.localDbPath,
      localBackupPath: localBackupPath ?? this.localBackupPath,
      cloudBaseUrl: cloudBaseUrl ?? this.cloudBaseUrl,
      cloudApiToken: cloudApiToken ?? this.cloudApiToken,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      observacao: observacao ?? this.observacao,
      bancoLocalPath: bancoLocalPath ?? this.bancoLocalPath,
      backupLocalPath: backupLocalPath ?? this.backupLocalPath,
      servidorLocalHost: servidorLocalHost ?? this.servidorLocalHost,
      servidorLocalPorta: servidorLocalPorta ?? this.servidorLocalPorta,
      nuvemBaseUrl: nuvemBaseUrl ?? this.nuvemBaseUrl,
      nuvemApiKey: nuvemApiKey ?? this.nuvemApiKey,
      usarCriptografia: usarCriptografia ?? this.usarCriptografia,
      sincronizacaoAtiva: sincronizacaoAtiva ?? this.sincronizacaoAtiva,
      intervaloMinutos: intervaloMinutos ?? this.intervaloMinutos,
      ultimaSincronizacao: ultimaSincronizacao ?? this.ultimaSincronizacao,
      connectionMode: connectionMode ?? this.connectionMode,
      localServerUrl: localServerUrl ?? this.localServerUrl,
      cloudServerUrl: cloudServerUrl ?? this.cloudServerUrl,
      portalUrl: portalUrl ?? this.portalUrl,
      sirePath: sirePath ?? this.sirePath,
      sireExternalPath: sireExternalPath ?? this.sireExternalPath,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'modo': modo,
      'localDbPath': localDbPath,
      'localBackupPath': localBackupPath,
      'cloudBaseUrl': cloudBaseUrl,
      'cloudApiToken': cloudApiToken,
      'syncEnabled': syncEnabled,
      'syncIntervalMinutes': syncIntervalMinutes,
      'lastSyncAt': lastSyncAt,
      'observacao': observacao,
      'bancoLocalPath': bancoLocalPath,
      'backupLocalPath': backupLocalPath,
      'servidorLocalHost': servidorLocalHost,
      'servidorLocalPorta': servidorLocalPorta,
      'nuvemBaseUrl': nuvemBaseUrl,
      'nuvemApiKey': nuvemApiKey,
      'usarCriptografia': usarCriptografia,
      'sincronizacaoAtiva': sincronizacaoAtiva,
      'intervaloMinutos': intervaloMinutos,
      'ultimaSincronizacao': ultimaSincronizacao,
      'connectionMode': connectionMode,
      'localServerUrl': localServerUrl,
      'cloudServerUrl': cloudServerUrl,
      'portalUrl': portalUrl,
      'sirePath': sirePath,
      'sireExternalPath': sireExternalPath,
    };
  }

  factory ServerConfig.fromJson(Map<String, Object?> json) {
    String value(String key, String fallback) {
      return json[key]?.toString() ?? fallback;
    }

    final String mode = value('modo', value('connectionMode', 'LOCAL'));
    final String host = value('servidorLocalHost', AppConstants.servidorLocalHost);
    final String port = value('servidorLocalPorta', AppConstants.servidorLocalPorta);
    final String cloudUrl = value('cloudBaseUrl', value('nuvemBaseUrl', ''));

    return ServerConfig(
      modo: mode,
      localDbPath: value('localDbPath', value('bancoLocalPath', AppConstants.bancoLocalPath)),
      localBackupPath: value('localBackupPath', value('backupLocalPath', AppConstants.backupLocalPath)),
      cloudBaseUrl: cloudUrl,
      cloudApiToken: value('cloudApiToken', value('nuvemApiKey', '')),
      syncEnabled: _normalBool(value('syncEnabled', value('sincronizacaoAtiva', '1'))),
      syncIntervalMinutes: value('syncIntervalMinutes', value('intervaloMinutos', '15')),
      lastSyncAt: value('lastSyncAt', value('ultimaSincronizacao', '')),
      observacao: value('observacao', ''),
      bancoLocalPath: value('bancoLocalPath', value('localDbPath', AppConstants.bancoLocalPath)),
      backupLocalPath: value('backupLocalPath', value('localBackupPath', AppConstants.backupLocalPath)),
      servidorLocalHost: host,
      servidorLocalPorta: port,
      nuvemBaseUrl: value('nuvemBaseUrl', cloudUrl),
      nuvemApiKey: value('nuvemApiKey', value('cloudApiToken', '')),
      usarCriptografia: _normalBool(value('usarCriptografia', '1')),
      sincronizacaoAtiva: _normalBool(value('sincronizacaoAtiva', value('syncEnabled', '1'))),
      intervaloMinutos: value('intervaloMinutos', value('syncIntervalMinutes', '15')),
      ultimaSincronizacao: value('ultimaSincronizacao', value('lastSyncAt', '')),
      connectionMode: value('connectionMode', mode),
      localServerUrl: value('localServerUrl', 'http://$host:$port'),
      cloudServerUrl: value('cloudServerUrl', cloudUrl),
      portalUrl: value('portalUrl', AppConstants.portalPacienteUrl),
      sirePath: value('sirePath', AppConstants.kristalSireShortcutPath),
      sireExternalPath: value('sireExternalPath', AppConstants.kristalSireExternalShortcutPath),
    );
  }

  static String _normalBool(String value) {
    final String normalized = value.toLowerCase().trim();
    return normalized == 'true' || normalized == '1' || normalized == 'sim'
        ? '1'
        : '0';
  }

  static const ServerConfig defaults = ServerConfig();
}

class ServerConfigService {
  ServerConfigService();

  static final ServerConfigService instance = ServerConfigService();

  Future<ServerConfig> getConfig() {
    return carregar();
  }

  Future<ServerConfig> load() {
    return carregar();
  }

  Future<ServerConfig> loadConfig() {
    return carregar();
  }

  Future<ServerConfig> carregar() async {
    final File file = File(AppConstants.serverConfigPath());

    if (!await file.exists()) {
      await salvar(config: ServerConfig.defaults);
      return ServerConfig.defaults;
    }

    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) {
        return ServerConfig.fromJson(decoded);
      }
    } on FileSystemException {
      return ServerConfig.defaults;
    } on FormatException {
      return ServerConfig.defaults;
    }

    return ServerConfig.defaults;
  }

  Future<void> save(ServerConfig config) {
    return salvar(config: config);
  }

  Future<void> saveConfig({
    Object? session,
    required ServerConfig config,
  }) {
    return salvar(config: config);
  }

  Future<void> salvar({
    Object? session,
    required ServerConfig config,
  }) async {
    final File file = File(AppConstants.serverConfigPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
    );
  }

  Future<void> updateLastSync({required String usuario}) {
    return marcarSincronizacao(usuario: usuario);
  }

  Future<void> marcarSincronizacao({required String usuario}) async {
    final ServerConfig current = await carregar();
    final String now = DateTime.now().toIso8601String();

    await salvar(
      config: current.copyWith(
        lastSyncAt: now,
        ultimaSincronizacao: now,
      ),
    );
  }
}
