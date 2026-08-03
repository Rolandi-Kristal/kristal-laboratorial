import 'dart:convert';
import 'dart:io';

class KristalDriverPath {
  static const String rootRelative =
      r'drivers\KRISTAL_LABORATORIAL\EQUIPAMENTOS';

  static String rootFromProject(String projectRoot) {
    return '$projectRoot\\$rootRelative';
  }

  static String bh5390(String projectRoot) {
    return '${rootFromProject(projectRoot)}\\BH-5390\\BH5390.drv';
  }

  static String bs360e(String projectRoot) {
    return '${rootFromProject(projectRoot)}\\BS360E\\BS360E_ASTM.drv';
  }

  static String audmax(String projectRoot) {
    return '${rootFromProject(projectRoot)}\\AUDMAX\\Audmax.drv';
  }

  static String audlyte(String projectRoot) {
    return '${rootFromProject(projectRoot)}\\AUDLYTE\\audlyte.old';
  }

  static String labmaxPremium(String projectRoot) {
    return '${rootFromProject(projectRoot)}\\LABMAX_PREMIUM\\LabmaxPremium.drv';
  }

  static String urivision720(String projectRoot) {
    return '${rootFromProject(projectRoot)}\\URIVISION720\\Urivision720.drv';
  }

  static String kristalAdvanceDllFolder(String projectRoot) {
    return '${rootFromProject(projectRoot)}\\KRISTAL_ADVANCE_DLL';
  }

  static String kristalAdvanceDllMain(String projectRoot) {
    return '${kristalAdvanceDllFolder(projectRoot)}\\ScelDLL.dll';
  }

  static String faturamentoSireExe(String projectRoot) {
    return '${rootFromProject(projectRoot)}\\FATURAMENTO_SIRE\\FaturamentoSIRE_Externos.exe';
  }
}

class KristalDriverManifestService {
  KristalDriverManifestService._();

  static final KristalDriverManifestService instance =
      KristalDriverManifestService._();

  Future<Map<String, dynamic>> readManifest(String projectRoot) async {
    final File file = File(
      '$projectRoot\\drivers\\KRISTAL_LABORATORIAL\\KRISTAL_DRIVER_MANIFEST.json',
    );

    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    final String content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listProfiles(String projectRoot) async {
    final Map<String, dynamic> manifest = await readManifest(projectRoot);
    final Object? rawProfiles = manifest['equipmentProfiles'];

    if (rawProfiles is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawProfiles
        .whereType<Map>()
        .map((Map item) => item.cast<String, dynamic>())
        .toList();
  }
}
