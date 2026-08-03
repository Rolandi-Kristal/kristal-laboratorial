import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/kristal_crypto_service.dart';
import 'audit_service.dart';
import 'lab_repository.dart';

class DatabaseExportSnapshotService {
  DatabaseExportSnapshotService._();

  static final DatabaseExportSnapshotService instance =
      DatabaseExportSnapshotService._();

  final LabRepository _repo = LabRepository();

  Future<String> exportarSnapshotCriptografado({
    required String usuario,
  }) async {
    final Map<String, dynamic> snapshot = <String, dynamic>{};

    final List<String> tables = <String>[
      'pacientes',
      'exames',
      'atendimentos',
      'agendamentos',
      'cadebens_integracao',
      'pedidos',
      'amostras',
      'resultados',
      'laudos',
      'equipamentos',
      'usuarios',
      'auditoria',
      'materiais',
      'estoque',
      'calibracoes',
      'manutencoes',
      'controle_qualidade',
      'configuracoes',
    ];

    for (final String table in tables) {
      snapshot[table] = await _repo.all(table);
    }

    final String json = jsonEncode(snapshot);
    final String encrypted =
        await KristalCryptoService.instance.encryptString(json);

    final Directory support = await getApplicationSupportDirectory();
    final Directory exportDir = Directory(p.join(support.path, 'snapshots'));

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    final File file = File(p.join(exportDir.path, 'snapshot_$stamp.krsnap'));

    await file.writeAsString(encrypted, flush: true);

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'EXPORTAR_SNAPSHOT',
      tabela: 'database',
      registroId: file.path,
      detalhes: 'Snapshot criptografado exportado.',
    );

    return file.path;
  }
}
