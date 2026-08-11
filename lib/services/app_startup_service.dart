import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
    } on DatabaseException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_SCHEMA', error, stackTrace);
      rethrow;
    } on FileSystemException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_SCHEMA', error, stackTrace);
      rethrow;
    }

    try {
      await SeedService.instance.instalarBaseInicial();
      await LogService.instance.info(
        'STARTUP',
        'Base inicial verificada/instalada.',
      );
    } on DatabaseException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_SEED', error, stackTrace);
      rethrow;
    } on FileSystemException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_SEED', error, stackTrace);
      rethrow;
    }

    try {
      await ServerSyncService.instance.iniciar(usuario: 'SISTEMA');
      await LogService.instance.info(
        'STARTUP',
        'Sincronização corporativa em tempo real iniciada.',
      );
    } on DatabaseException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_SYNC', error, stackTrace);
    } on FileSystemException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_SYNC', error, stackTrace);
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
    } on DatabaseException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_BACKUP', error, stackTrace);
    } on FileSystemException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_BACKUP', error, stackTrace);
    } on FormatException catch (error, stackTrace) {
      await LogService.instance.error('STARTUP_BACKUP', error, stackTrace);
    }
  }
}
