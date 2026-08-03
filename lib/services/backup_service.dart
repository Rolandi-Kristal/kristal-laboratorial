import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_constants.dart';
import '../security/kristal_crypto_service.dart';
import 'audit_service.dart';
import 'database_service.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  Future<File> criarBackupManual() async {
    final String origem = await DatabaseService.instance.databasePath();
    final File dbFile = File(origem);

    final Directory support = await getApplicationSupportDirectory();
    final Directory backupDir = Directory(p.join(support.path, 'backups'));

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    final String destino = p.join(
      backupDir.path,
      'kristal_lab_backup_$stamp${AppConstants.backupExtension}',
    );

    final File target = File(destino);

    if (!await dbFile.exists()) {
      await target.writeAsString('BANCO_AINDA_NAO_CRIADO', flush: true);
      return target;
    }

    final List<int> bytes = await dbFile.readAsBytes();
    final String encrypted =
        await KristalCryptoService.instance.encryptString(base64Encode(bytes));

    await target.writeAsString(encrypted, flush: true);

    await AuditService.instance.registrar(
      acao: 'BACKUP_MANUAL',
      tabela: 'database',
      registroId: destino,
      detalhes: 'Backup manual criptografado gerado.',
    );

    return target;
  }
}
