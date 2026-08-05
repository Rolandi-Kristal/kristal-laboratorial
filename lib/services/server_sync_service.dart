import 'dart:async';

import 'audit_service.dart';
import 'corporate_sync_service.dart';
import 'server_config_service.dart';

class ServerSyncService {
  ServerSyncService._();

  static final ServerSyncService instance = ServerSyncService._();

  static const Duration _intervaloCorporativo = Duration(seconds: 5);

  Timer? _timer;
  bool _running = false;

  bool get running => _running;

  Future<void> iniciar({required String usuario}) async {
    if (_running) return;

    await CorporateSyncService.instance.ensureSchema();
    _timer?.cancel();
    _timer = Timer.periodic(
      _intervaloCorporativo,
      (_) => unawaited(
        sincronizarAgora(
          usuario: usuario,
          registrarAuditoria: false,
        ),
      ),
    );
    _running = true;

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'INICIAR_SYNC_SERVIDOR',
      tabela: 'configuracoes',
      registroId: 'server_config',
      detalhes:
          'Sincronização corporativa iniciada a cada ${_intervaloCorporativo.inSeconds} segundos.',
    );

    await sincronizarAgora(
      usuario: usuario,
      registrarAuditoria: false,
    );
  }

  Future<void> parar({required String usuario}) async {
    _timer?.cancel();
    _timer = null;
    _running = false;

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'PARAR_SYNC_SERVIDOR',
      tabela: 'configuracoes',
      registroId: 'server_config',
      detalhes: 'Sincronização corporativa parada.',
    );
  }

  Future<String> sincronizarAgora({
    required String usuario,
    bool registrarAuditoria = true,
  }) async {
    final CorporateSyncResult result =
        await CorporateSyncService.instance.synchronize();

    if (!result.ok) {
      if (registrarAuditoria) {
        await AuditService.instance.registrar(
          usuario: usuario,
          acao: 'SINCRONIZAR_SERVIDOR_FALHA',
          tabela: 'configuracoes',
          registroId: 'server_config',
          detalhes: result.message,
        );
      }
      return result.message;
    }

    await ServerConfigService.instance.marcarSincronizacao(usuario: usuario);
    if (registrarAuditoria || result.pushed > 0 || result.pulled > 0) {
      await AuditService.instance.registrar(
        usuario: usuario,
        acao: 'SINCRONIZAR_AGORA',
        tabela: 'configuracoes',
        registroId: 'server_config',
        detalhes:
            'Enviados=${result.pushed}; recebidos=${result.pulled}; servidor corporativo confirmado.',
      );
    }

    return '${result.message} Enviados: ${result.pushed}; recebidos: ${result.pulled}.';
  }
}
