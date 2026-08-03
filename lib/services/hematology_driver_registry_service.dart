import 'dart:convert';
import 'dart:io';

import '../models/hematology_driver_profile.dart';

class HematologyDriverRegistryService {
  HematologyDriverRegistryService._();

  static final HematologyDriverRegistryService instance =
      HematologyDriverRegistryService._();

  Directory get baseDirectory =>
      Directory(r'D:\kristal_laboratorial\data\drivers\hematologia');

  File get profilesFile =>
      File('${baseDirectory.path}\\hematologia_driver_profiles.json');

  Future<List<HematologyDriverProfile>> loadProfiles() async {
    await baseDirectory.create(recursive: true);

    if (!await profilesFile.exists()) {
      return <HematologyDriverProfile>[];
    }

    final String content = await profilesFile.readAsString(encoding: utf8);
    final Object? decoded = jsonDecode(content);

    if (decoded is! Map<String, dynamic>) {
      return <HematologyDriverProfile>[];
    }

    final List<dynamic> rows =
        decoded['modelos'] as List<dynamic>? ?? <dynamic>[];

    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> row) => HematologyDriverProfile.fromJson(
            row.map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, Object?>(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, Object?>> validateDriverPack() async {
    await baseDirectory.create(recursive: true);
    final Directory packageDir = Directory('${baseDirectory.path}\\pacote');
    final File rar = File('${baseDirectory.path}\\driver hemato.rar');

    return <String, Object?>{
      'baseDirectory': baseDirectory.path,
      'profilesFile': profilesFile.path,
      'driverPackCopied': await rar.exists(),
      'driverPackExtracted': await packageDir.exists(),
      'profiles': (await loadProfiles()).length,
    };
  }
}
