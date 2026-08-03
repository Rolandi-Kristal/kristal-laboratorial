import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import '../models/lab_exam_definition.dart';
import 'audit_service.dart';
import 'auth_service.dart';

class LabExamCatalogImportResult {
  const LabExamCatalogImportResult({
    required this.importedCount,
    required this.archivedPath,
    required this.sha256,
    required this.message,
  });

  final int importedCount;
  final String archivedPath;
  final String sha256;
  final String message;
}

class LabExamCatalogService {
  LabExamCatalogService._();

  static final LabExamCatalogService instance = LabExamCatalogService._();

  static const List<LabExamDefinition> _seed = <LabExamDefinition>[
    LabExamDefinition(
        code: 'HEM',
        name: 'Hemograma completo',
        sector: 'Hematologia',
        material: 'Sangue total EDTA',
        sireCode: '0202020380',
        synonyms: <String>['CBC', 'hemograma']),
    LabExamDefinition(
        code: 'VHS',
        name: 'Velocidade de hemossedimentação',
        sector: 'Hematologia',
        material: 'Sangue citratado',
        sireCode: '0202020150',
        synonyms: <String>['ESR', 'VHS']),
    LabExamDefinition(
        code: 'RET',
        name: 'Reticulócitos',
        sector: 'Hematologia',
        material: 'Sangue total EDTA',
        sireCode: '0202020259',
        synonyms: <String>['reticulocitos']),
    LabExamDefinition(
        code: 'TAP',
        name: 'Tempo de protrombina / INR',
        sector: 'Hemostasia',
        material: 'Plasma citratado',
        sireCode: '0202020143',
        synonyms: <String>['TP', 'INR']),
    LabExamDefinition(
        code: 'TTPA',
        name: 'Tempo de tromboplastina parcial ativada',
        sector: 'Hemostasia',
        material: 'Plasma citratado',
        sireCode: '0202020135',
        synonyms: <String>['PTT', 'APTT']),
    LabExamDefinition(
        code: 'FIB',
        name: 'Fibrinogênio',
        sector: 'Hemostasia',
        material: 'Plasma citratado',
        sireCode: '0202020186',
        synonyms: <String>['fibrinogenio']),
    LabExamDefinition(
        code: 'DD',
        name: 'D-dímero',
        sector: 'Hemostasia',
        material: 'Plasma citratado',
        sireCode: '0202020500',
        synonyms: <String>['d dimero']),
    LabExamDefinition(
        code: 'GLI',
        name: 'Glicose',
        sector: 'Bioquímica',
        material: 'Soro ou plasma fluoretado',
        sireCode: '0202010473',
        synonyms: <String>['glicemia'],
        unit: 'mg/dL',
        requiresFasting: true,
        isCriticalTrackable: true),
    LabExamDefinition(
        code: 'HBA1C',
        name: 'Hemoglobina glicada',
        sector: 'Bioquímica',
        material: 'Sangue total EDTA',
        sireCode: '0202010503',
        synonyms: <String>['A1C', 'HbA1c'],
        unit: '%'),
    LabExamDefinition(
        code: 'URE',
        name: 'Ureia',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010694',
        synonyms: <String>['ureia']),
    LabExamDefinition(
        code: 'CRE',
        name: 'Creatinina',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010317',
        synonyms: <String>['creatinina'],
        isCriticalTrackable: true),
    LabExamDefinition(
        code: 'COL',
        name: 'Colesterol total',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010295',
        synonyms: <String>['colesterol']),
    LabExamDefinition(
        code: 'HDL',
        name: 'Colesterol HDL',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010279',
        synonyms: <String>['HDL']),
    LabExamDefinition(
        code: 'LDL',
        name: 'Colesterol LDL',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010287',
        synonyms: <String>['LDL']),
    LabExamDefinition(
        code: 'TRI',
        name: 'Triglicerídeos',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010678',
        synonyms: <String>['triglicerides']),
    LabExamDefinition(
        code: 'TGO',
        name: 'AST/TGO',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010643',
        synonyms: <String>['AST']),
    LabExamDefinition(
        code: 'TGP',
        name: 'ALT/TGP',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010651',
        synonyms: <String>['ALT']),
    LabExamDefinition(
        code: 'GGT',
        name: 'Gama GT',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010465',
        synonyms: <String>['GGT']),
    LabExamDefinition(
        code: 'FA',
        name: 'Fosfatase alcalina',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010422',
        synonyms: <String>['FAL']),
    LabExamDefinition(
        code: 'BT',
        name: 'Bilirrubina total e frações',
        sector: 'Bioquímica',
        material: 'Soro',
        sireCode: '0202010201',
        synonyms: <String>['bilirrubina'],
        isCriticalTrackable: true),
    LabExamDefinition(
        code: 'NA',
        name: 'Sódio',
        sector: 'Eletrólitos',
        material: 'Soro',
        sireCode: '0202010635',
        synonyms: <String>['sodio'],
        isCriticalTrackable: true),
    LabExamDefinition(
        code: 'K',
        name: 'Potássio',
        sector: 'Eletrólitos',
        material: 'Soro',
        sireCode: '0202010600',
        synonyms: <String>['potassio'],
        isCriticalTrackable: true),
    LabExamDefinition(
        code: 'CL',
        name: 'Cloro',
        sector: 'Eletrólitos',
        material: 'Soro',
        sireCode: '0202010260',
        synonyms: <String>['cloro']),
    LabExamDefinition(
        code: 'GASO',
        name: 'Gasometria arterial',
        sector: 'Gasometria',
        material: 'Sangue arterial heparinizado',
        sireCode: '0202010457',
        synonyms: <String>['gasometria'],
        isCriticalTrackable: true),
    LabExamDefinition(
        code: 'EAS',
        name: 'Urina tipo I / EAS',
        sector: 'Uroanálise',
        material: 'Urina',
        sireCode: '0202050017',
        synonyms: <String>['urina tipo 1']),
    LabExamDefinition(
        code: 'UROC',
        name: 'Urocultura',
        sector: 'Microbiologia',
        material: 'Urina',
        sireCode: '0202080080',
        synonyms: <String>['urocultura']),
    LabExamDefinition(
        code: 'TSH',
        name: 'Hormônio tireoestimulante',
        sector: 'Hormônios',
        material: 'Soro',
        sireCode: '0202060250',
        synonyms: <String>['TSH']),
    LabExamDefinition(
        code: 'T4L',
        name: 'Tiroxina livre',
        sector: 'Hormônios',
        material: 'Soro',
        sireCode: '0202060373',
        synonyms: <String>['T4 livre', 'FT4']),
    LabExamDefinition(
        code: 'T3',
        name: 'Triiodotironina',
        sector: 'Hormônios',
        material: 'Soro',
        sireCode: '0202060390',
        synonyms: <String>['T3']),
    LabExamDefinition(
        code: 'LH',
        name: 'Hormônio luteinizante',
        sector: 'Hormônios',
        material: 'Soro',
        sireCode: '0202060218',
        synonyms: <String>['LH']),
    LabExamDefinition(
        code: 'FSH',
        name: 'Hormônio folículo estimulante',
        sector: 'Hormônios',
        material: 'Soro',
        sireCode: '0202060200',
        synonyms: <String>['FSH']),
    LabExamDefinition(
        code: 'PRL',
        name: 'Prolactina',
        sector: 'Hormônios',
        material: 'Soro',
        sireCode: '0202060293',
        synonyms: <String>['prolactina']),
    LabExamDefinition(
        code: 'BHCG',
        name: 'Beta HCG',
        sector: 'Imunoquímica',
        material: 'Soro',
        sireCode: '0202060210',
        synonyms: <String>['gravidez', 'beta']),
    LabExamDefinition(
        code: 'VITD',
        name: '25 Hidroxi Vitamina D',
        sector: 'Hormônios',
        material: 'Soro',
        sireCode: '0202060560',
        synonyms: <String>['vitamina D']),
    LabExamDefinition(
        code: 'PCR',
        name: 'Proteína C reativa',
        sector: 'Imunologia',
        material: 'Soro',
        sireCode: '0202030203',
        synonyms: <String>['CRP']),
    LabExamDefinition(
        code: 'FR',
        name: 'Fator reumatoide',
        sector: 'Imunologia',
        material: 'Soro',
        sireCode: '0202030076',
        synonyms: <String>['FR']),
    LabExamDefinition(
        code: 'FAN',
        name: 'Fator antinuclear',
        sector: 'Imunologia',
        material: 'Soro',
        sireCode: '0202030598',
        synonyms: <String>['ANA']),
    LabExamDefinition(
        code: 'HIV',
        name: 'HIV 1/2',
        sector: 'Sorologia',
        material: 'Soro',
        sireCode: '0202031021',
        synonyms: <String>['HIV']),
    LabExamDefinition(
        code: 'HBSAG',
        name: 'HBsAg',
        sector: 'Sorologia',
        material: 'Soro',
        sireCode: '0202030971',
        synonyms: <String>['hepatite B']),
    LabExamDefinition(
        code: 'HCV',
        name: 'Anti-HCV',
        sector: 'Sorologia',
        material: 'Soro',
        sireCode: '0202031005',
        synonyms: <String>['hepatite C']),
    LabExamDefinition(
        code: 'VDRL',
        name: 'VDRL',
        sector: 'Sorologia',
        material: 'Soro',
        sireCode: '0202031110',
        synonyms: <String>['sifilis']),
    LabExamDefinition(
        code: 'DENGUE',
        name: 'Dengue NS1/IgM/IgG',
        sector: 'Sorologia',
        material: 'Soro',
        sireCode: '0202031200',
        synonyms: <String>['dengue']),
    LabExamDefinition(
        code: 'COVID',
        name: 'SARS-CoV-2',
        sector: 'Biologia Molecular',
        material: 'Swab nasofaríngeo',
        sireCode: '0202031251',
        synonyms: <String>['covid']),
    LabExamDefinition(
        code: 'PSA',
        name: 'PSA total',
        sector: 'Marcadores tumorais',
        material: 'Soro',
        sireCode: '0202030238',
        synonyms: <String>['PSA']),
    LabExamDefinition(
        code: 'CEA',
        name: 'Antígeno carcinoembrionário',
        sector: 'Marcadores tumorais',
        material: 'Soro',
        sireCode: '0202030270',
        synonyms: <String>['CEA']),
    LabExamDefinition(
        code: 'CA125',
        name: 'CA 125',
        sector: 'Marcadores tumorais',
        material: 'Soro',
        sireCode: '0202030246',
        synonyms: <String>['CA125']),
    LabExamDefinition(
        code: 'HCULT',
        name: 'Hemocultura',
        sector: 'Microbiologia',
        material: 'Sangue',
        sireCode: '0202080064',
        synonyms: <String>['hemocultura']),
    LabExamDefinition(
        code: 'COPROC',
        name: 'Coprocultura',
        sector: 'Microbiologia',
        material: 'Fezes',
        sireCode: '0202080030',
        synonyms: <String>['coprocultura']),
    LabExamDefinition(
        code: 'PARA',
        name: 'Parasitológico de fezes',
        sector: 'Parasitologia',
        material: 'Fezes',
        sireCode: '0202040011',
        synonyms: <String>['EPF']),
    LabExamDefinition(
        code: 'GRAM',
        name: 'Bacterioscopia Gram',
        sector: 'Microbiologia',
        material: 'Diversos',
        sireCode: '0202080013',
        synonyms: <String>['gram']),
    LabExamDefinition(
        code: 'BAAR',
        name: 'Pesquisa de BAAR',
        sector: 'Microbiologia',
        material: 'Escarro ou amostra clínica',
        sireCode: '0202080110',
        synonyms: <String>['tuberculose']),
    LabExamDefinition(
        code: 'TIPO',
        name: 'Tipagem sanguínea ABO/Rh',
        sector: 'Imuno-hematologia',
        material: 'Sangue total EDTA',
        sireCode: '0202120022',
        synonyms: <String>['ABO', 'RH']),
    LabExamDefinition(
        code: 'TROP',
        name: 'Troponina',
        sector: 'Urgência',
        material: 'Soro ou plasma',
        sireCode: '0202010783',
        synonyms: <String>['troponina'],
        isCriticalTrackable: true),
    LabExamDefinition(
        code: 'PCT',
        name: 'Procalcitonina',
        sector: 'Urgência',
        material: 'Soro',
        sireCode: '0202031308',
        synonyms: <String>['procalcitonina'],
        isCriticalTrackable: true),
  ];

  List<LabExamDefinition>? _cache;

  Future<List<LabExamDefinition>> load({bool includeDeleted = false}) async {
    final List<LabExamDefinition> items = await _loadMerged();
    return items
        .where((LabExamDefinition exam) => includeDeleted || !exam.deleted)
        .toList(growable: false);
  }

  Future<LabExamDefinition?> findByCode(String code) async {
    final String normalized = code.trim().toUpperCase();
    final List<LabExamDefinition> items = await load(includeDeleted: true);
    for (final LabExamDefinition exam in items) {
      if (exam.code.toUpperCase() == normalized) {
        return exam;
      }
    }
    return null;
  }

  Future<List<LabExamDefinition>> identifyByCodes(
      Iterable<String> codes) async {
    final List<LabExamDefinition> items = await load();
    final Map<String, LabExamDefinition> byCode = <String, LabExamDefinition>{
      for (final LabExamDefinition exam in items) exam.code.toUpperCase(): exam,
    };
    final List<LabExamDefinition> result = <LabExamDefinition>[];
    final Set<String> used = <String>{};

    for (final String rawCode in codes) {
      final String normalized = rawCode.trim().toUpperCase();
      final LabExamDefinition? exam = byCode[normalized];
      if (exam != null && used.add(exam.code)) {
        result.add(exam);
      }
    }

    return result;
  }

  Future<List<LabExamDefinition>> search(String query,
      {bool includeDeleted = false}) async {
    final String normalized = _normalize(query);
    final List<LabExamDefinition> items = await load();
    if (normalized.isEmpty) {
      return items;
    }

    return items.where((LabExamDefinition exam) {
      final String text = _normalize(
        '${exam.code} ${exam.name} ${exam.sector} ${exam.material} '
        '${exam.sireCode} ${exam.synonyms.join(' ')}',
      );
      return text.contains(normalized);
    }).toList(growable: false);
  }

  Future<void> salvar({
    required LabExamDefinition exam,
    required AuthSession session,
  }) async {
    _assertCanEdit(session);
    final String code = exam.code.trim().toUpperCase();
    final String name = exam.name.trim();
    if (code.isEmpty || name.isEmpty) {
      throw ArgumentError('MNE/código e nome do exame são obrigatórios.');
    }
    final List<LabExamDefinition> items = await load(includeDeleted: true);
    final int index = items.indexWhere(
      (LabExamDefinition item) => item.code.toUpperCase() == code,
    );
    final LabExamDefinition normalized = exam.copyWith(
      code: code,
      name: name,
      updatedAt: DateTime.now().toIso8601String(),
      updatedBy: session.login,
      deleted: false,
    );
    if (index >= 0) {
      items[index] = normalized;
    } else {
      items.add(normalized);
    }
    await _saveAll(items);
    await _audit(session, 'SALVAR_CATALOGO_EXAME', code, name);
  }

  Future<void> inativar(
      {required String code, required AuthSession session}) async {
    _assertCanEdit(session);
    await _updateStatus(
      code: code,
      session: session,
      active: false,
      deleted: false,
      action: 'INATIVAR_CATALOGO_EXAME',
    );
  }

  Future<void> reativar(
      {required String code, required AuthSession session}) async {
    _assertCanEdit(session);
    await _updateStatus(
      code: code,
      session: session,
      active: true,
      deleted: false,
      action: 'REATIVAR_CATALOGO_EXAME',
    );
  }

  Future<void> excluirLogicamente(
      {required String code, required AuthSession session}) async {
    if (!session.isSuperUser) {
      throw StateError(
          'Apenas SUPER_USUARIO pode excluir registros do catálogo.');
    }
    await _updateStatus(
      code: code,
      session: session,
      active: false,
      deleted: true,
      action: 'EXCLUIR_LOGICAMENTE_CATALOGO_EXAME',
    );
  }

  Future<LabExamCatalogImportResult> importarArquivo({
    required String path,
    required AuthSession session,
  }) async {
    _assertCanEdit(session);
    final File source = File(path);
    if (!await source.exists()) {
      throw FileSystemException('Arquivo de importação não encontrado.', path);
    }
    final List<int> bytes = await source.readAsBytes();
    final String fileHash = sha256.convert(bytes).toString();
    final Directory archiveDir = Directory(
      p.join(AppConstants.dataDirectoryPath, 'importacoes', 'catalogo_exames'),
    );
    await archiveDir.create(recursive: true);
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final String archiveName =
        '${timestamp}_${fileHash.substring(0, 12)}_${p.basename(path)}';
    final File archived = File(p.join(archiveDir.path, archiveName));
    await source.copy(archived.path);

    final List<LabExamDefinition> parsed =
        _parseImport(bytes: bytes, fileName: source.path);
    for (final LabExamDefinition exam in parsed) {
      await salvar(exam: exam, session: session);
    }
    await _audit(
      session,
      'IMPORTAR_CATALOGO_EXAMES',
      fileHash,
      'Arquivo=; registros=',
    );
    return LabExamCatalogImportResult(
      importedCount: parsed.length,
      archivedPath: archived.path,
      sha256: fileHash,
      message: parsed.isEmpty
          ? 'Arquivo aceito e arquivado permanentemente. Nenhum registro estruturado foi identificado.'
          : 'Arquivo aceito, arquivado e integrado ao catálogo.',
    );
  }

  List<LabExamDefinition> _parseImport(
      {required List<int> bytes, required String fileName}) {
    final String extension = p.extension(fileName).toLowerCase();
    final String text = _decodeText(bytes);
    if (text.trim().isEmpty) {
      return const <LabExamDefinition>[];
    }
    if (extension == '.json') {
      final Object? decoded = jsonDecode(text);
      final Object? list = decoded is Map
          ? (decoded['exames'] ?? decoded['catalogo'] ?? decoded['data'])
          : decoded;
      if (list is List) {
        return list
            .whereType<Map>()
            .map((Map item) {
              return LabExamDefinition.fromJson(
                item.map((dynamic key, dynamic value) =>
                    MapEntry<String, Object?>(key.toString(), value)),
              );
            })
            .where(_isImportValid)
            .toList(growable: false);
      }
      return const <LabExamDefinition>[];
    }
    if (extension == '.csv' || extension == '.tsv' || extension == '.txt') {
      final String separator =
          extension == '.tsv' ? '\t' : _detectSeparator(text);
      return _parseDelimited(text, separator)
          .where(_isImportValid)
          .toList(growable: false);
    }
    return const <LabExamDefinition>[];
  }

  List<LabExamDefinition> _parseDelimited(String text, String separator) {
    final List<String> lines = text
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return const <LabExamDefinition>[];
    }
    final List<String> headers = lines.first
        .split(separator)
        .map(_normalizeHeader)
        .toList(growable: false);
    final List<LabExamDefinition> exams = <LabExamDefinition>[];
    for (final String line in lines.skip(1)) {
      final List<String> values = line.split(separator);
      final Map<String, String> row = <String, String>{};
      for (int index = 0;
          index < headers.length && index < values.length;
          index++) {
        row[headers[index]] = values[index].trim();
      }
      exams.add(
        LabExamDefinition(
          code: row['mne'] ?? row['codigo'] ?? row['code'] ?? '',
          name: row['nome'] ?? row['exame'] ?? row['name'] ?? '',
          sector: row['setor'] ?? row['sector'] ?? '',
          material: row['material'] ?? '',
          sireCode:
              row['codigosire'] ?? row['codigo_sire'] ?? row['sire'] ?? '',
          synonyms: (row['sinonimos'] ?? row['synonyms'] ?? '')
              .split('|')
              .map((String value) => value.trim())
              .where((String value) => value.isNotEmpty)
              .toList(growable: false),
          unit: row['unidade'] ?? row['unit'] ?? '',
          reference: row['referencia'] ?? row['reference'] ?? '',
          active: (row['ativo'] ?? '1') != '0',
        ),
      );
    }
    return exams;
  }

  bool _isImportValid(LabExamDefinition exam) {
    return exam.code.trim().isNotEmpty && exam.name.trim().isNotEmpty;
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _detectSeparator(String text) {
    final List<String> lines = text.split(RegExp(r'\r?\n'));
    final String firstLine = lines.isEmpty ? '' : lines.first;
    final Map<String, int> scores = <String, int>{
      ';': ';'.allMatches(firstLine).length,
      ',': ','.allMatches(firstLine).length,
      '|': '|'.allMatches(firstLine).length,
      '\t': '\t'.allMatches(firstLine).length,
    };
    return scores.entries
        .reduce((MapEntry<String, int> a, MapEntry<String, int> b) =>
            a.value >= b.value ? a : b)
        .key;
  }

  String _normalizeHeader(String value) {
    return _normalize(value).replaceAll(RegExp(r'[^a-z0-9_]+'), '');
  }

  Future<void> _updateStatus({
    required String code,
    required AuthSession session,
    required bool active,
    required bool deleted,
    required String action,
  }) async {
    final List<LabExamDefinition> items = await load(includeDeleted: true);
    final String normalizedCode = code.trim().toUpperCase();
    final int index = items.indexWhere(
      (LabExamDefinition item) => item.code.toUpperCase() == normalizedCode,
    );
    if (index < 0) {
      throw StateError('Exame não localizado no catálogo: ');
    }
    final LabExamDefinition updated = items[index].copyWith(
      active: active,
      deleted: deleted,
      updatedAt: DateTime.now().toIso8601String(),
      updatedBy: session.login,
    );
    items[index] = updated;
    await _saveAll(items);
    await _audit(session, action, normalizedCode, updated.name);
  }

  Future<List<LabExamDefinition>> _loadMerged() async {
    if (_cache != null) {
      return List<LabExamDefinition>.from(_cache!);
    }
    final Map<String, LabExamDefinition> byCode = <String, LabExamDefinition>{
      for (final LabExamDefinition exam in _seed) exam.code.toUpperCase(): exam,
    };
    final File file = await _catalogFile();
    if (await file.exists()) {
      final String content = await file.readAsString(encoding: utf8);
      final Object? decoded = jsonDecode(content);
      if (decoded is! List) {
        throw const FormatException('Arquivo permanente do catálogo inválido.');
      }
      for (final Object? item in decoded) {
        if (item is Map) {
          final LabExamDefinition exam = LabExamDefinition.fromJson(
            item.map((dynamic key, dynamic value) =>
                MapEntry<String, Object?>(key.toString(), value)),
          );
          if (exam.code.trim().isNotEmpty) {
            byCode[exam.code.toUpperCase()] = exam;
          }
        }
      }
    }
    final List<LabExamDefinition> merged = byCode.values.toList(growable: true)
      ..sort((LabExamDefinition a, LabExamDefinition b) =>
          a.name.compareTo(b.name));
    _cache = merged;
    return List<LabExamDefinition>.from(merged);
  }

  Future<void> _saveAll(List<LabExamDefinition> items) async {
    final File file = await _catalogFile();
    await file.parent.create(recursive: true);
    final List<LabExamDefinition> normalized = items.toList(growable: true)
      ..sort((LabExamDefinition a, LabExamDefinition b) =>
          a.name.compareTo(b.name));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        normalized
            .map((LabExamDefinition exam) => exam.toJson())
            .toList(growable: false),
      ),
      encoding: utf8,
    );
    _cache = normalized;
  }

  Future<File> _catalogFile() async {
    return File(p.join(
        AppConstants.dataDirectoryPath, 'catalogo_exames_permanente.json'));
  }

  void _assertCanEdit(AuthSession session) {
    if (!session.isSuperUser && !session.isAdmin) {
      throw StateError(
          'Apenas SUPER_USUARIO ou ADMINISTRADOR pode editar o catálogo de exames.');
    }
  }

  Future<void> _audit(
      AuthSession session, String action, String code, String details) async {
    await AuditService.instance.registrar(
      usuario: session.login,
      acao: action,
      tabela: 'catalogo_exames',
      registroId: code,
      detalhes: details,
    );
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp('[áàãâä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòõôö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .trim();
  }
}
