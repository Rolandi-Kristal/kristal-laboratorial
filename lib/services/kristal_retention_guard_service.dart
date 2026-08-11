import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_constants.dart';

class KristalRetentionGuardService {
  KristalRetentionGuardService._();

  static final KristalRetentionGuardService instance =
      KristalRetentionGuardService._();

  static final Set<String> protectedTables =
      Set<String>.unmodifiable(AppConstants.protectedClinicalTables);

  Future<int> arquivarSemExcluir({
    required Database database,
    required String table,
    required String id,
    required String motivo,
    String? session,
  }) async {
    if (!protectedTables.contains(table)) {
      throw ArgumentError.value(
        table,
        'table',
        'Tabela fora da lista protegida do KRISTAL.',
      );
    }

    final String now = DateTime.now().toIso8601String();

    return database.transaction<int>((Transaction txn) async {
      final int updated = await txn.update(
        table,
        <String, Object?>{
          'ativoConsultaRecente': '0',
          'arquivado': '1',
          'excluidoFisicamente': '0',
          'bloqueioExclusao': '1',
          'arquivadoEm': now,
          'motivoArquivamento': motivo,
          'atualizadoEm': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      await txn.insert(
        'auditoria',
        <String, Object?>{
          'id': 'audit_${DateTime.now().microsecondsSinceEpoch}',
          'usuario': session ?? 'SISTEMA',
          'acao': 'ARQUIVAMENTO_LOGICO_PERMANENTE',
          'tabela': table,
          'registroId': id,
          'dataHora': now,
          'detalhes': motivo,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return updated;
    });
  }
}
