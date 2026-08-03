import 'dart:async';

import 'audit_service.dart';
import 'server_config_service.dart';
import 'server_connection_service.dart';

class ServerSyncService {
  ServerSyncService._();

  static final ServerSyncService instance = ServerSyncService._();

  Timer? _timer;
  bool _running = false;

  bool get running => _running;

  Future<void> iniciar({
    required String usuario,
  }) async {
    if (_running) return;

    final ServerConfig config = await ServerConfigService.instance.carregar();

    if (config.sincronizacaoAtiva != '1') return;

    final int minutos = int.tryParse(config.intervaloMinutos.trim()) ?? 15;

    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: minutos <= 0 ? 15 : minutos),
      (_) => sincronizarAgora(usuario: usuario),
    );

    _running = true;

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'INICIAR_SYNC_SERVIDOR',
      tabela: 'configuracoes',
      registroId: 'server_config',
      detalhes: 'Sincronização automática iniciada.',
    );
  }

  Future<void> parar({
    required String usuario,
  }) async {
    _timer?.cancel();
    _timer = null;
    _running = false;

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'PARAR_SYNC_SERVIDOR',
      tabela: 'configuracoes',
      registroId: 'server_config',
      detalhes: 'Sincronização automática parada.',
    );
  }

  Future<String> sincronizarAgora({
    required String usuario,
  }) async {
    final ServerConfig config = await ServerConfigService.instance.carregar();

    if (config.isLocal || config.isHibrido) {
      final ServerConnectionResult local =
          await ServerConnectionService.instance.exportarSnapshotLocal(
        usuario: usuario,
        config: config,
      );

      if (!local.ok) return local.message;
    }

    if (config.isNuvem || config.isHibrido) {
      final ServerConnectionResult nuvem =
          await ServerConnectionService.instance.testarNuvem(config);

      if (!nuvem.ok) {
        return 'Snapshot local executado quando aplicável. Nuvem não confirmou: ${nuvem.message}';
      }
    }

    await ServerConfigService.instance.marcarSincronizacao(usuario: usuario);

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'SINCRONIZAR_AGORA',
      tabela: 'configuracoes',
      registroId: 'server_config',
      detalhes: 'Sincronização executada no modo ${config.modo}.',
    );

    return 'Sincronização executada no modo ${config.modo}.';
  }
}