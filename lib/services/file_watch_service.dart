import 'dart:io';
import '../models/equipment_connection_config.dart';

class FileWatchResult {
  final bool ok;
  final String message;
  final List<File> files;
  const FileWatchResult(
      {required this.ok, required this.message, required this.files});
}

class FileWatchService {
  FileWatchService._();
  static final FileWatchService instance = FileWatchService._();

  Future<FileWatchResult> listarArquivosPendentes(
      EquipmentConnectionConfig config) async {
    final Directory inputDir = Directory(config.pastaEntrada.trim());
    if (!await inputDir.exists()) {
      return FileWatchResult(
          ok: false,
          message: 'Pasta de entrada não existe: ${inputDir.path}',
          files: const <File>[]);
    }
    final List<String> extensions = config.extensoesMonitoradas
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final List<File> files = <File>[];
    await for (final FileSystemEntity entity in inputDir.list()) {
      if (entity is! File) continue;
      final String lower = entity.path.toLowerCase();
      if (extensions.isEmpty || extensions.any(lower.endsWith)) {
        files.add(entity);
      }
    }
    return FileWatchResult(
        ok: true,
        message: '${files.length} arquivo(s) encontrado(s).',
        files: files);
  }

  Future<String> lerArquivo(File file) => file.readAsString();

  Future<void> moverParaProcessados(
      {required File file, required EquipmentConnectionConfig config}) async {
    if (config.pastaSaida.trim().isEmpty) return;
    final Directory outputDir = Directory(config.pastaSaida.trim());
    if (!await outputDir.exists()) await outputDir.create(recursive: true);
    final String name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'resultado_${DateTime.now().millisecondsSinceEpoch}.txt';
    await file.rename('${outputDir.path}${Platform.pathSeparator}$name');
  }
}
