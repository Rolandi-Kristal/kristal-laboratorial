import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import '../models/professional_signature_model.dart';

class ProfessionalSignatureService {
  ProfessionalSignatureService._();

  static final ProfessionalSignatureService instance =
      ProfessionalSignatureService._();

  static const Set<String> allowedExtensions = <String>{
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
  };

  Future<ProfessionalSignatureModel> load() async {
    final File file = await _configFile();

    if (!await file.exists()) {
      await save(ProfessionalSignatureModel.empty());
      return ProfessionalSignatureModel.empty();
    }

    final String content = await file.readAsString(encoding: utf8);
    final Object? decoded = jsonDecode(content);

    if (decoded is! Map) {
      await save(ProfessionalSignatureModel.empty());
      return ProfessionalSignatureModel.empty();
    }

    return ProfessionalSignatureModel.fromJson(
      decoded.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, Object?>(key.toString(), value),
      ),
    );
  }

  Future<void> save(ProfessionalSignatureModel model) async {
    final File file = await _configFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(model.toJson()),
      encoding: utf8,
    );
  }

  Future<String> importSignatureFile(String sourcePath) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Arquivo de assinatura não encontrado.');
    }

    final String extension = p.extension(source.path).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw FileSystemException(
        'Formato não permitido. Use PDF, JPG, JPEG ou PNG.',
        source.path,
      );
    }

    final Directory directory = Directory(
      p.join(AppConstants.dataDirectoryPath, 'assinaturas'),
    );
    await directory.create(recursive: true);

    final String fileName =
        'assinatura_${DateTime.now().millisecondsSinceEpoch}$extension';
    final File target = File(p.join(directory.path, fileName));
    await source.copy(target.path);

    return target.path;
  }

  bool isPdf(String path) {
    return p.extension(path).toLowerCase() == '.pdf';
  }

  bool isImage(String path) {
    final String extension = p.extension(path).toLowerCase();
    return extension == '.jpg' || extension == '.jpeg' || extension == '.png';
  }

  Future<File> _configFile() async {
    final Directory directory = Directory(
      p.join(AppConstants.dataDirectoryPath, 'profissionais'),
    );
    await directory.create(recursive: true);
    return File(p.join(directory.path, 'assinatura_profissional.json'));
  }
}
