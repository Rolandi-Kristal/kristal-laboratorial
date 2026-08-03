import 'dart:convert';
import 'dart:io';

import '../security/kristal_crypto_service.dart';
import 'audit_service.dart';
import 'auth_service.dart';
import 'database_service.dart';

class BackupRestoreService {
  BackupRestoreService._();

  static final BackupRestoreService instance = BackupRestoreService._();

  Future<void> restaurarBackup({
    required AuthSession session,
    required String backupPath,
  }) async {
    if (!session.isSuperUser) {
      throw StateError('Somente o Superusuário pode restaurar backup.');
    }

    final File backup = File(backupPath);

    if (!await backup.exists()) {
      throw StateError('Arquivo de backup não encontrado.');
    }

    final String encrypted = await backup.readAsString();
    final String decoded =
        await KristalCryptoService.instance.decryptString(encrypted);

    final List<int> bytes = base64Decode(decoded);
    final String databasePath = await DatabaseService.instance.databasePath();

    await File(databasePath).writeAsBytes(bytes, flush: true);

    await AuditService.instance.registrar(
      usuario: session.login,
      acao: 'RESTAURAR_BACKUP',
      tabela: 'database',
      registroId: backupPath,
      detalhes: 'Backup restaurado pelo superusuário.',
    );
  }
}
