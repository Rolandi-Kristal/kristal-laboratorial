import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import '../models/kristal_operational_record.dart';

class KristalOperationalStoreService {
  KristalOperationalStoreService._();

  static final KristalOperationalStoreService instance =
      KristalOperationalStoreService._();

  Future<List<KristalOperationalRecord>> load(String module) async {
    final File file = await _fileForModule(module);

    if (!await file.exists()) {
      await file.writeAsString('[]', encoding: utf8);
      return <KristalOperationalRecord>[];
    }

    final String content = await file.readAsString(encoding: utf8);
    final Object? decoded = jsonDecode(content);

    if (decoded is! List) {
      await file.writeAsString('[]', encoding: utf8);
      return <KristalOperationalRecord>[];
    }

    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => KristalOperationalRecord.fromJson(
            item.map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, Object?>(key.toString(), value),
            ),
          ),
        )
        .where((KristalOperationalRecord record) => record.id.isNotEmpty)
        .toList(growable: true);
  }

  Future<KristalOperationalRecord> create({
    required String module,
    required Map<String, String> data,
  }) async {
    final List<KristalOperationalRecord> records = await load(module);
    final DateTime now = DateTime.now();

    final KristalOperationalRecord record = KristalOperationalRecord(
      id: now.microsecondsSinceEpoch.toString(),
      module: module,
      data: data,
      createdAt: now,
      updatedAt: now,
      activeRecent: true,
      archived: false,
    );

    records.insert(0, record);
    await _save(module, records);
    return record;
  }

  Future<void> archive({
    required String module,
    required String id,
    required String reason,
  }) async {
    final List<KristalOperationalRecord> records = await load(module);
    final DateTime now = DateTime.now();

    final List<KristalOperationalRecord> updated =
        records.map((KristalOperationalRecord record) {
      if (record.id == id) {
        return record.copyWith(
          activeRecent: false,
          archived: true,
          archivedAt: now,
          archiveReason: reason,
          updatedAt: now,
        );
      }
      return record;
    }).toList(growable: true);

    await _save(module, updated);
  }

  Future<File> exportJson(String module) async {
    final List<KristalOperationalRecord> records = await load(module);
    final Directory directory = Directory(
      p.join(AppConstants.exportsDirectoryPath, 'modulos_operacionais'),
    );
    await directory.create(recursive: true);

    final File file = File(
      p.join(
        directory.path,
        '${_safeName(module)}_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        records
            .map((KristalOperationalRecord record) => record.toJson())
            .toList(),
      ),
      encoding: utf8,
    );

    return file;
  }

  Future<Map<String, int>> countsByModule(List<String> modules) async {
    final Map<String, int> counts = <String, int>{};

    for (final String module in modules) {
      final List<KristalOperationalRecord> records = await load(module);
      counts[module] = records
          .where(
            (KristalOperationalRecord record) =>
                record.activeRecent && !record.archived,
          )
          .length;
    }

    return counts;
  }

  Future<void> _save(
    String module,
    List<KristalOperationalRecord> records,
  ) async {
    final File file = await _fileForModule(module);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        records
            .map((KristalOperationalRecord record) => record.toJson())
            .toList(),
      ),
      encoding: utf8,
    );
  }

  Future<File> _fileForModule(String module) async {
    final Directory directory = Directory(
      p.join(AppConstants.dataDirectoryPath, 'modulos_operacionais'),
    );
    await directory.create(recursive: true);
    return File(p.join(directory.path, '${_safeName(module)}.json'));
  }

  String _safeName(String module) {
    return module.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  }
}
