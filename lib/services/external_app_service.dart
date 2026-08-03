import 'dart:io';

class ExternalAppService {
  const ExternalAppService();

  Future<void> openExecutable(String path) async {
    if (!Platform.isWindows) {
      throw const FileSystemException(
        'Integração externa disponível apenas no Windows.',
      );
    }

    final File file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Executável não encontrado.', path);
    }

    final ProcessResult result = await Process.run(
      'cmd',
      <String>['/c', 'start', '', file.path],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw FileSystemException(
        result.stderr?.toString() ?? 'Falha ao abrir executável.',
        path,
      );
    }
  }

  Future<void> openDirectory(String path) async {
    if (!Platform.isWindows) {
      throw const FileSystemException(
        'Abertura de pasta disponível apenas no Windows.',
      );
    }

    final Directory directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final ProcessResult result = await Process.run(
      'explorer.exe',
      <String>[directory.path],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw FileSystemException(
        result.stderr?.toString() ?? 'Falha ao abrir pasta.',
        path,
      );
    }
  }
}
