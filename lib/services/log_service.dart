import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LogService {
  LogService._();

  static final LogService instance = LogService._();

  static const int maxBytes = 5 * 1024 * 1024;
  static const int maxFiles = 5;

  Future<Directory> _logDir() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(support.path, 'logs'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<File> _currentFile() async {
    final Directory dir = await _logDir();
    final String date = DateTime.now().toIso8601String().split('T').first;
    return File(p.join(dir.path, 'kristal_lab_$date.log'));
  }

  Future<void> info(String tag, String message) {
    return write('INFO', tag, message);
  }

  Future<void> warning(String tag, String message) {
    return write('WARN', tag, message);
  }

  Future<void> error(String tag, Object error, [StackTrace? stackTrace]) {
    return write(
      'ERROR',
      tag,
      stackTrace == null ? error.toString() : '$error\n$stackTrace',
    );
  }

  Future<void> write(String level, String tag, String message) async {
    final File file = await _currentFile();
    final String now = DateTime.now().toIso8601String();

    await file.writeAsString(
      '[$now][$level][$tag] $message\n',
      mode: FileMode.append,
      flush: true,
    );

    await _rotateIfNeeded(file);
    await _cleanupOldLogs();
  }

  Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) return;

    final int length = await file.length();

    if (length <= maxBytes) return;

    final String rotatedPath =
        '${file.path}.${DateTime.now().millisecondsSinceEpoch}.old';

    await file.rename(rotatedPath);
  }

  Future<void> _cleanupOldLogs() async {
    final Directory dir = await _logDir();
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<File> files = entities.whereType<File>().toList()
      ..sort(
        (File a, File b) =>
            b.statSync().modified.compareTo(a.statSync().modified),
      );
    if (files.length <= maxFiles) return;

    final Directory archive = Directory(p.join(dir.path, 'archive'));
    if (!await archive.exists()) {
      await archive.create(recursive: true);
    }
    for (final File file in files.skip(maxFiles)) {
      final String destination = p.join(
        archive.path,
        '${p.basename(file.path)}.'
        '${DateTime.now().microsecondsSinceEpoch}.archived',
      );
      try {
        await file.rename(destination);
      } on FileSystemException catch (error, stackTrace) {
        stderr.writeln(
          '[${DateTime.now().toIso8601String()}][ERROR][LOG_ARCHIVE] '
          '${error.message} path=${error.path ?? ''} '
          'destination=$destination stack=$stackTrace',
        );
      }
    }
  }

  Future<String> logFolderPath() async {
    return (await _logDir()).path;
  }
}
