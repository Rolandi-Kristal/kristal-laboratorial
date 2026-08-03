import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import 'kristal_operational_store_service.dart';

class UserDocumentImportResult {
  const UserDocumentImportResult({
    required this.imported,
    required this.archivedPath,
    required this.sha256Hash,
    required this.message,
  });

  final int imported;
  final String archivedPath;
  final String sha256Hash;
  final String message;
}

class UserDocumentImportService {
  UserDocumentImportService._();

  static final UserDocumentImportService instance =
      UserDocumentImportService._();

  static const Set<String> _validProfiles = <String>{
    'SUPER_USUARIO',
    'ADMINISTRADOR',
    'RESPONSAVEL_TECNICO',
    'BIOQUIMICO',
    'FARMACEUTICO',
    'BIOMEDICO',
    'MEDICO',
    'ENFERMAGEM',
    'TECNICO_LABORATORIO',
    'RECEPCAO',
    'COLETA',
    'FATURAMENTO_SIRE',
    'AUDITORIA',
    'CONSULTA',
  };

  static const Set<String> _validStatuses = <String>{
    'ATIVO',
    'INATIVO',
    'BLOQUEADO',
    'SUSPENSO',
    'AGUARDANDO_LIBERACAO',
  };

  Future<UserDocumentImportResult> importFile(String sourcePath) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
          'Documento de usuários não encontrado.', sourcePath);
    }

    final List<int> bytes = await source.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Documento de usuários está vazio.');
    }

    final String hash = sha256.convert(bytes).toString();
    final String archivedPath =
        await _archiveOriginal(source: source, hash: hash);
    final String extension =
        p.extension(source.path).toLowerCase().replaceFirst('.', '');

    final List<Map<String, String>> users = switch (extension) {
      'json' => _parseJson(utf8.decode(bytes, allowMalformed: false)),
      'csv' => _parseDelimited(utf8.decode(bytes, allowMalformed: false), ','),
      'tsv' => _parseDelimited(utf8.decode(bytes, allowMalformed: false), '\t'),
      'txt' => _parseText(utf8.decode(bytes, allowMalformed: false)),
      _ => <Map<String, String>>[],
    };

    for (final Map<String, String> user in users) {
      await KristalOperationalStoreService.instance.create(
        module: 'usuarios',
        data: user,
      );
    }

    if (users.isEmpty) {
      return UserDocumentImportResult(
        imported: 0,
        archivedPath: archivedPath,
        sha256Hash: hash,
        message:
            'Documento arquivado com HASH, mas sem usuários estruturados para integrar. Use JSON, CSV, TSV ou TXT com colunas nome, usuario, perfil e status.',
      );
    }

    return UserDocumentImportResult(
      imported: users.length,
      archivedPath: archivedPath,
      sha256Hash: hash,
      message:
          '${users.length} usuário(s) importado(s) e documento arquivado com HASH.',
    );
  }

  Future<String> _archiveOriginal(
      {required File source, required String hash}) async {
    final Directory directory = Directory(
      p.join(AppConstants.dataDirectoryPath, 'importacoes', 'usuarios'),
    );
    await directory.create(recursive: true);
    final String safeBaseName =
        p.basename(source.path).replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
    final String targetPath = p.join(
      directory.path,
      '${DateTime.now().millisecondsSinceEpoch}_${hash.substring(0, 16)}_$safeBaseName',
    );
    await source.copy(targetPath);
    await File('$targetPath.sha256')
        .writeAsString(hash, encoding: utf8, flush: true);
    return targetPath;
  }

  List<Map<String, String>> _parseJson(String content) {
    final Object? decoded = jsonDecode(content);
    final Object? source = decoded is Map<String, Object?>
        ? decoded['usuarios'] ??
            decoded['users'] ??
            decoded['data'] ??
            decoded['registros']
        : decoded;
    if (source is! List) {
      throw const FormatException(
          'JSON de usuários deve conter uma lista ou a chave usuarios/users/data.');
    }
    return source
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> item) => _normalizeUser(item))
        .where((Map<String, String> item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, String>> _parseText(String content) {
    final String delimiter = _detectDelimiter(content);
    return _parseDelimited(content, delimiter);
  }

  List<Map<String, String>> _parseDelimited(
      String content, String preferredDelimiter) {
    final List<String> lines = const LineSplitter()
        .convert(content)
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      throw const FormatException('Documento de usuários sem linhas úteis.');
    }

    final String delimiter =
        preferredDelimiter == ',' && !lines.first.contains(',')
            ? _detectDelimiter(content)
            : preferredDelimiter;
    final List<String> first = _splitDelimitedLine(lines.first, delimiter);
    final bool hasHeader =
        first.any((String value) => _canonicalKey(value).isNotEmpty);
    final List<String> headers = hasHeader
        ? first.map(_canonicalKey).toList(growable: false)
        : <String>['nome', 'usuario', 'perfil', 'status'];
    final Iterable<String> dataLines = hasHeader ? lines.skip(1) : lines;

    final List<Map<String, String>> users = <Map<String, String>>[];
    for (final String line in dataLines) {
      final List<String> values = _splitDelimitedLine(line, delimiter);
      final Map<String, String> raw = <String, String>{};
      for (int index = 0;
          index < headers.length && index < values.length;
          index++) {
        if (headers[index].isNotEmpty) {
          raw[headers[index]] = values[index].trim();
        }
      }
      final Map<String, String> normalized = _normalizeUser(raw);
      if (normalized.isNotEmpty) {
        users.add(normalized);
      }
    }
    return users;
  }

  String _detectDelimiter(String content) {
    final String firstLine = const LineSplitter().convert(content).firstWhere(
          (String line) => line.trim().isNotEmpty,
          orElse: () => '',
        );
    final Map<String, int> counts = <String, int>{
      ';': ';'.allMatches(firstLine).length,
      ',': ','.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
      '|': '|'.allMatches(firstLine).length,
    };
    return counts.entries
        .reduce((MapEntry<String, int> a, MapEntry<String, int> b) {
      return a.value >= b.value ? a : b;
    }).key;
  }

  List<String> _splitDelimitedLine(String line, String delimiter) {
    final List<String> values = <String>[];
    final StringBuffer current = StringBuffer();
    bool quoted = false;
    for (int i = 0; i < line.length; i++) {
      final String char = line[i];
      if (char == '"') {
        quoted = !quoted;
        continue;
      }
      if (!quoted && line.startsWith(delimiter, i)) {
        values.add(current.toString());
        current.clear();
        i += delimiter.length - 1;
        continue;
      }
      current.write(char);
    }
    values.add(current.toString());
    return values;
  }

  Map<String, String> _normalizeUser(Map<dynamic, dynamic> raw) {
    final Map<String, String> normalized = <String, String>{};
    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      final String key = _canonicalKey(entry.key.toString());
      if (key.isNotEmpty) {
        normalized[key] = entry.value?.toString().trim() ?? '';
      }
    }

    final String name = normalized['nome'] ?? '';
    final String username = normalized['usuario'] ?? '';
    if (name.isEmpty || username.isEmpty) {
      return <String, String>{};
    }

    final String profile =
        (normalized['perfil'] ?? 'CONSULTA').trim().toUpperCase();
    final String status =
        (normalized['status'] ?? 'ATIVO').trim().toUpperCase();

    return <String, String>{
      'nome': name,
      'usuario': username,
      'perfil': _validProfiles.contains(profile) ? profile : 'CONSULTA',
      'status': _validStatuses.contains(status) ? status : 'ATIVO',
      if ((normalized['email'] ?? '').isNotEmpty) 'email': normalized['email']!,
      if ((normalized['telefone'] ?? '').isNotEmpty)
        'telefone': normalized['telefone']!,
      if ((normalized['documento'] ?? '').isNotEmpty)
        'documento': normalized['documento']!,
    };
  }

  String _canonicalKey(String value) {
    final String key =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return switch (key) {
      'nome' || 'name' || 'nomedousuario' || 'usuarioNome' => 'nome',
      'usuario' || 'user' || 'login' || 'username' || 'matricula' => 'usuario',
      'perfil' || 'profile' || 'funcao' || 'role' => 'perfil',
      'status' || 'situacao' => 'status',
      'email' || 'mail' => 'email',
      'telefone' || 'celular' || 'phone' => 'telefone',
      'cpf' || 'documento' || 'identidade' => 'documento',
      _ => '',
    };
  }
}
