import 'backup_scheduler_service.dart';
import 'log_service.dart';
import 'schema_migration_service.dart';
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
      BackupSchedulerService.instance.configure(
        enabled: true,
        interval: const Duration(hours: 24),
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
