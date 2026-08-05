import 'backup_scheduler_service.dart';
import 'config_service.dart';
import 'log_service.dart';
import 'schema_migration_service.dart';
import 'server_sync_service.dart';
import 'seed_service.dart';

class AppStartupService {
  AppStartupService._();

  static final AppStartupService instance = AppStartupService._();

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await LogService.instance.info(
      'STARTUP',
      'Inicializando serviços da KRISTAL LABORATORIAL.',
    );

    try {
      await SchemaMigrationService.instance.ensureSchema();

      await LogService.instance.info(
        'STARTUP',
        'Migração/verificação de schema concluída.',
      );
    } catch (e, s) {
      await LogService.instance.error('STARTUP_SCHEMA', e, s);
    }

    try {
      await SeedService.instance.instalarBaseInicial();

      await LogService.instance.info(
        'STARTUP',
        'Base inicial verificada/instalada.',
      );
    } catch (e, s) {
      await LogService.instance.error('STARTUP_SEED', e, s);
    }

    try {
      await ServerSyncService.instance.iniciar(usuario: 'SISTEMA');

      await LogService.instance.info(
        'STARTUP',
        'Sincronização corporativa em tempo real iniciada.',
      );
    } catch (e, s) {
      await LogService.instance.error('STARTUP_SYNC', e, s);
    }

    try {
      final String horarioBackup = await ConfigService.instance.getValue(
        'backup_automatico_hora',
        defaultValue: '23:00',
      );
      BackupSchedulerService.instance.configureDaily(
        enabled: true,
        horario: horarioBackup,
      );

      await LogService.instance.info(
        'STARTUP',
        'Backup automático diário ativado.',
      );
    } catch (e, s) {
      await LogService.instance.error('STARTUP_BACKUP', e, s);
    }
  }
}
