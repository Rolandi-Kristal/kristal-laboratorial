import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audit_service.dart';
import 'lab_repository.dart';

class ExportCsvService {
  ExportCsvService._();

  static final ExportCsvService instance = ExportCsvService._();

  final LabRepository _repo = LabRepository();

  Future<String> exportarTabela({
    required String tabela,
    String usuario = 'SISTEMA',
  }) async {
    final List<Map<String, dynamic>> rows = await _repo.all(tabela);

    final Directory dir = await getApplicationSupportDirectory();
    final Directory exportDir = Directory(p.join(dir.path, 'exports'));

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final String stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    final File file = File(p.join(exportDir.path, '${tabela}_$stamp.csv'));

    if (rows.isEmpty) {
      await file.writeAsString('sem_dados\n', encoding: utf8, flush: true);
    } else {
      final List<String> headers = rows.first.keys.toList();
      final StringBuffer buffer = StringBuffer();

      buffer.writeln(headers.map(_escapeCsv).join(';'));

      for (final Map<String, dynamic> row in rows) {
        buffer.writeln(
          headers
              .map((String h) => _escapeCsv(row[h]?.toString() ?? ''))
              .join(';'),
        );
      }

      await file.writeAsString(buffer.toString(), encoding: utf8, flush: true);
    }

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'EXPORTAR_CSV',
      tabela: tabela,
      registroId: file.path,
      detalhes: 'Exportação CSV realizada.',
    );

    return file.path;
  }

  String _escapeCsv(String input) {
    final String normalized = input.replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (normalized.contains(';') || normalized.contains('"')) {
      return '"${normalized.replaceAll('"', '""')}"';
    }
    return normalized;
  }
}
