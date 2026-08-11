import 'dart:convert';
import 'dart:io';

class KristalIntegrationProfile {
  final String id;
  final String displayName;
  final String folder;
  final String mainFile;
  final String connectionType;
  final String protocol;

  const KristalIntegrationProfile({
    required this.id,
    required this.displayName,
    required this.folder,
    required this.mainFile,
    required this.connectionType,
    required this.protocol,
  });

  factory KristalIntegrationProfile.fromMap(Map<String, dynamic> map) {
    return KristalIntegrationProfile(
      id: map['id']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      folder: map['folder']?.toString() ?? '',
      mainFile: map['mainFile']?.toString() ??
          map['mainLibrary']?.toString() ??
          map['mainPackage']?.toString() ??
          '',
      connectionType: map['connectionType']?.toString() ?? '',
      protocol: map['protocol']?.toString() ?? '',
    );
  }

  String fullPath(String projectRoot) {
    return '$projectRoot\\KRISTAL_LABORATORIAL\\INTEGRACOES\\$folder\\$mainFile';
  }
}

class KristalIntegrationManifestService {
  KristalIntegrationManifestService._();

  static final KristalIntegrationManifestService instance =
      KristalIntegrationManifestService._();

  static const String manifestRelativePath =
      r'KRISTAL_LABORATORIAL\KRISTAL_INTEGRACOES_MANIFEST.json';

  static const String integrationsRootRelativePath =
      r'KRISTAL_LABORATORIAL\INTEGRACOES';

  String integrationsRoot(String projectRoot) {
    return '$projectRoot\\$integrationsRootRelativePath';
  }

  Future<Map<String, dynamic>> readManifest(String projectRoot) async {
    final File file = File('$projectRoot\\$manifestRelativePath');

    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    final String content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<List<KristalIntegrationProfile>> listProfiles(
      String projectRoot) async {
    final Map<String, dynamic> manifest = await readManifest(projectRoot);
    final Object? raw = manifest['modules'];

    if (raw is! List) {
      return <KristalIntegrationProfile>[];
    }

    return raw
        .whereType<Map>()
        .map((Map item) =>
            KristalIntegrationProfile.fromMap(item.cast<String, dynamic>()))
        .toList();
  }
}
