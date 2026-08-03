import 'dart:io';

import '../core/app_constants.dart';

class KristalSireLauncherService {
  const KristalSireLauncherService();

  Future<bool> isKristalSireInstalled() async {
    final bool shortcutExists = await File(AppConstants.kristalSireShortcutPath).exists();
    final bool coreExists = await File(AppConstants.kristalSireCoreExecutablePath).exists();
    return shortcutExists && coreExists;
  }

  Future<bool> isKristalSireExternalInstalled() async {
    final bool shortcutExists =
        await File(AppConstants.kristalSireExternalShortcutPath).exists();
    final bool coreExists =
        await File(AppConstants.kristalSireExternalCoreExecutablePath).exists();
    return shortcutExists && coreExists;
  }

  Future<void> openKristalSire() async {
    await _openShortcutOrCore(
      shortcutPath: AppConstants.kristalSireShortcutPath,
      corePath: AppConstants.kristalSireCoreExecutablePath,
      name: 'KRISTAL SIRE',
    );
  }

  Future<void> openKristalSireExternal() async {
    await _openShortcutOrCore(
      shortcutPath: AppConstants.kristalSireExternalShortcutPath,
      corePath: AppConstants.kristalSireExternalCoreExecutablePath,
      name: 'KRISTAL SIRE EXTERNOS',
    );
  }

  Future<void> openSireExportDirectory() async {
    final Directory directory =
        Directory(AppConstants.kristalSireExportDirectoryPath);
    await directory.create(recursive: true);
    await Process.run('explorer.exe', <String>[directory.path], runInShell: true);
  }

  Future<void> _openShortcutOrCore({
    required String shortcutPath,
    required String corePath,
    required String name,
  }) async {
    final File shortcut = File(shortcutPath);
    final File core = File(corePath);

    final String targetPath;
    if (await shortcut.exists()) {
      targetPath = shortcut.path;
    } else if (await core.exists()) {
      targetPath = core.path;
    } else {
      throw FileSystemException('$name não encontrado.', corePath);
    }

    final ProcessResult result = await Process.run(
      'cmd',
      <String>['/c', 'start', '', targetPath],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw FileSystemException('Falha ao iniciar $name.', targetPath);
    }
  }
}
