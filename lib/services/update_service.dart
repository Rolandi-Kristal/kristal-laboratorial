import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_constants.dart';
import 'audit_service.dart';

class UpdatePackageInfo {
  final String path;
  final String version;
  final String createdAt;

  const UpdatePackageInfo({
    required this.path,
    required this.version,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'path': path,
      'version': version,
      'createdAt': createdAt,
    };
  }
}

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  Future<String> updateFolderPath() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(support.path, 'updates'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir.path;
  }

  Future<List<UpdatePackageInfo>> listarPacotes() async {
    final Directory dir = Directory(await updateFolderPath());

    final List<FileSystemEntity> entities = await dir.list().toList();

    final List<UpdatePackageInfo> packages = <UpdatePackageInfo>[];

    for (final File file in entities.whereType<File>()) {
      if (!file.path.toLowerCase().endsWith('.zip') &&
          !file.path.toLowerCase().endsWith('.msix') &&
          !file.path.toLowerCase().endsWith('.msi') &&
          !file.path.toLowerCase().endsWith('.exe')) {
        continue;
      }

      packages.add(
        UpdatePackageInfo(
          path: file.path,
          version: _extractVersion(file.path),
          createdAt: file.statSync().modified.toIso8601String(),
        ),
      );
    }

    packages.sort((UpdatePackageInfo a, UpdatePackageInfo b) {
      return b.createdAt.compareTo(a.createdAt);
    });

    return packages;
  }

  Future<String> registrarPacote({
    required String sourcePath,
    required String usuario,
  }) async {
    final File source = File(sourcePath);

    if (!await source.exists()) {
      throw StateError('Pacote de atualização não encontrado.');
    }

    final Directory dir = Directory(await updateFolderPath());
    final String targetPath = p.join(dir.path, p.basename(source.path));

    await source.copy(targetPath);

    final File manifest = File(p.join(dir.path, 'update_manifest.json'));

    final Map<String, dynamic> data = <String, dynamic>{
      'app': AppConstants.appName,
      'currentVersion': AppConstants.version,
      'packagePath': targetPath,
      'registeredAt': DateTime.now().toIso8601String(),
    };

    await manifest.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );

    await AuditService.instance.registrar(
      usuario: usuario,
      acao: 'REGISTRAR_UPDATE',
      tabela: 'updates',
      registroId: targetPath,
      detalhes: 'Pacote de atualização registrado localmente.',
    );

    return targetPath;
  }

  String _extractVersion(String path) {
    final RegExp regex = RegExp(r'(\d+\.\d+\.\d+)');
    final Match? match = regex.firstMatch(path);
    return match?.group(1) ?? 'desconhecida';
  }
}
