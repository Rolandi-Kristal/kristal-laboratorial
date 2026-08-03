import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import 'lab_repository.dart';

class PatientDocumentImportResult {
  const PatientDocumentImportResult({
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

class PatientDocumentImportService {
  PatientDocumentImportService._();

  static final PatientDocumentImportService instance =
      PatientDocumentImportService._();

  final LabRepository _repo = LabRepository();

  Future<PatientDocumentImportResult> importFile(String sourcePath) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException(
          'Documento de pacientes não encontrado.', sourcePath);
    }
    final List<int> bytes = await source.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Documento de pacientes está vazio.');
    }

    final String hash = sha256.convert(bytes).toString();
    final String archivedPath =
        await _archiveOriginal(source: source, hash: hash);
    final String extension =
        p.extension(source.path).toLowerCase().replaceFirst('.', '');
    final String text = _decodeText(bytes);

    final List<Map<String, String>> patients = switch (extension) {
      'json' => _parseJson(text),
      'csv' => _parseDelimited(text, ','),
      'tsv' => _parseDelimited(text, '\t'),
      'txt' => _parseDelimited(text, _detectDelimiter(text)),
      _ => <Map<String, String>>[],
    };

    for (final Map<String, String> patient in patients) {
      await _repo.upsert('pacientes', patient, usuario: 'IMPORTACAO_PACIENTES');
    }

    if (patients.isEmpty) {
      return PatientDocumentImportResult(
        imported: 0,
        archivedPath: archivedPath,
        sha256Hash: hash,
        message:
            'Arquivo aceito e arquivado com HASH, mas sem pacientes estruturados para integrar. Use JSON, CSV, TSV ou TXT com nome e CPF/PREC-CP.',
      );
    }

    return PatientDocumentImportResult(
      imported: patients.length,
      archivedPath: archivedPath,
      sha256Hash: hash,
      message:
          '${patients.length} paciente(s) importado(s) e documento arquivado com HASH.',
    );
  }

  Future<String> _archiveOriginal(
      {required File source, required String hash}) async {
    final Directory directory = Directory(
      p.join(AppConstants.dataDirectoryPath, 'importacoes', 'pacientes'),
    );
    await directory.create(recursive: true);
    final String safeBaseName =
        p.basename(source.path).replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
    final String targetPath = p.join(directory.path,
        '${DateTime.now().millisecondsSinceEpoch}_${hash.substring(0, 16)}_$safeBaseName');
    await source.copy(targetPath);
    await File('$targetPath.sha256')
        .writeAsString(hash, encoding: utf8, flush: true);
    return targetPath;
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  List<Map<String, String>> _parseJson(String content) {
    final Object? decoded = jsonDecode(content);
    final Object? source = decoded is Map<String, Object?>
        ? decoded['pacientes'] ??
            decoded['patients'] ??
            decoded['data'] ??
            decoded['registros']
        : decoded;
    if (source is! List) {
      throw const FormatException(
          'JSON de pacientes deve conter lista ou chave pacientes/patients/data.');
    }
    return source
        .whereType<Map<dynamic, dynamic>>()
        .map(_normalizePatient)
        .where((Map<String, String> item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, String>> _parseDelimited(
      String content, String preferredDelimiter) {
    final List<String> lines = const LineSplitter()
        .convert(content)
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      throw const FormatException('Documento sem linhas úteis.');
    }
    final String delimiter =
        preferredDelimiter == ',' && !lines.first.contains(',')
            ? _detectDelimiter(content)
            : preferredDelimiter;
    final List<String> first = _splitLine(lines.first, delimiter);
    final bool hasHeader =
        first.any((String value) => _canonicalKey(value).isNotEmpty);
    final List<String> headers = hasHeader
        ? first.map(_canonicalKey).toList(growable: false)
        : <String>['nome', 'cpf', 'preccp', 'telefone'];
    final Iterable<String> dataLines = hasHeader ? lines.skip(1) : lines;
    final List<Map<String, String>> output = <Map<String, String>>[];
    for (final String line in dataLines) {
      final List<String> values = _splitLine(line, delimiter);
      final Map<String, String> raw = <String, String>{};
      for (int i = 0; i < headers.length && i < values.length; i++) {
        if (headers[i].isNotEmpty) {
          raw[headers[i]] = values[i].trim();
        }
      }
      final Map<String, String> normalized = _normalizePatient(raw);
      if (normalized.isNotEmpty) output.add(normalized);
    }
    return output;
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
        .reduce((MapEntry<String, int> a, MapEntry<String, int> b) =>
            a.value >= b.value ? a : b)
        .key;
  }

  List<String> _splitLine(String line, String delimiter) {
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

  Map<String, String> _normalizePatient(Map<dynamic, dynamic> raw) {
    final Map<String, String> normalized = <String, String>{};
    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      final String key = _canonicalKey(entry.key.toString());
      if (key.isNotEmpty) {
        normalized[key] = entry.value?.toString().trim() ?? '';
      }
    }
    final String nome = normalized['nome'] ?? '';
    final String cpf = _digits(normalized['cpf'] ?? '');
    final String preccp = normalized['preccp'] ?? '';
    if (nome.isEmpty || (cpf.isEmpty && preccp.isEmpty)) {
      return <String, String>{};
    }
    final String idBase =
        cpf.isNotEmpty ? cpf : preccp.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
    return <String, String>{
      'id': 'PAC-$idBase',
      'nome': nome,
      'cpf': cpf,
      'preccp': preccp,
      'cns': normalized['cns'] ?? '',
      'nascimento': normalized['nascimento'] ?? '',
      'telefone': normalized['telefone'] ?? '',
      'endereco': normalized['endereco'] ?? '',
      'status': (normalized['status'] ?? 'ATIVO').toUpperCase(),
      'criadoEm': DateTime.now().toIso8601String(),
    };
  }

  String _canonicalKey(String value) {
    final String key =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return switch (key) {
      'nome' ||
      'name' ||
      'paciente' ||
      'nomepaciente' ||
      'nomedopaciente' =>
        'nome',
      'cpf' => 'cpf',
      'preccp' || 'prec' || 'prec_cp' || 'preccpbeneficiario' => 'preccp',
      'cns' || 'cartaosus' => 'cns',
      'nascimento' || 'datanascimento' || 'dtNascimento' => 'nascimento',
      'telefone' || 'celular' || 'phone' => 'telefone',
      'endereco' || 'address' => 'endereco',
      'status' || 'situacao' => 'status',
      _ => '',
    };
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D+'), '');
}
