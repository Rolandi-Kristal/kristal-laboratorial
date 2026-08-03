import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import '../models/technical_responsible_model.dart';

class TechnicalResponsibleService {
  TechnicalResponsibleService._();

  static final TechnicalResponsibleService instance =
      TechnicalResponsibleService._();

  Future<TechnicalResponsibleModel> load() async {
    final File file = await _configFile();

    if (!await file.exists()) {
      await save(TechnicalResponsibleModel.empty());
      return TechnicalResponsibleModel.empty();
    }

    final String content = await file.readAsString(encoding: utf8);
    final Object? decoded = jsonDecode(content);

    if (decoded is! Map) {
      await save(TechnicalResponsibleModel.empty());
      return TechnicalResponsibleModel.empty();
    }

    return TechnicalResponsibleModel.fromJson(
      decoded.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, Object?>(key.toString(), value),
      ),
    );
  }

  Future<void> save(TechnicalResponsibleModel model) async {
    final File file = await _configFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(model.toJson()),
      encoding: utf8,
    );
  }

  Future<File> _configFile() async {
    final Directory directory = Directory(
      p.join(AppConstants.dataDirectoryPath, 'responsavel_tecnico'),
    );
    await directory.create(recursive: true);
    return File(p.join(directory.path, 'responsavel_tecnico.json'));
  }
}
