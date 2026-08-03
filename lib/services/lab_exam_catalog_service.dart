import '../models/lab_exam_definition.dart';

class LabExamCatalogService {
  LabExamCatalogService._();

  static final LabExamCatalogService instance = LabExamCatalogService._();

  static const List<LabExamDefinition> _seed = <LabExamDefinition>[
    LabExamDefinition(code: 'HEM', name: 'Hemograma completo', sector: 'Hematologia', material: 'Sangue total EDTA', sireCode: '0202020380', synonyms: <String>['CBC', 'hemograma']),
    LabExamDefinition(code: 'VHS', name: 'Velocidade de hemossedimentação', sector: 'Hematologia', material: 'Sangue citratado', sireCode: '0202020150', synonyms: <String>['ESR', 'VHS']),
    LabExamDefinition(code: 'RET', name: 'Reticulócitos', sector: 'Hematologia', material: 'Sangue total EDTA', sireCode: '0202020259', synonyms: <String>['reticulocitos']),
    LabExamDefinition(code: 'TAP', name: 'Tempo de protrombina / INR', sector: 'Hemostasia', material: 'Plasma citratado', sireCode: '0202020143', synonyms: <String>['TP', 'INR']),
    LabExamDefinition(code: 'TTPA', name: 'Tempo de tromboplastina parcial ativada', sector: 'Hemostasia', material: 'Plasma citratado', sireCode: '0202020135', synonyms: <String>['PTT', 'APTT']),
    LabExamDefinition(code: 'FIB', name: 'Fibrinogênio', sector: 'Hemostasia', material: 'Plasma citratado', sireCode: '0202020186', synonyms: <String>['fibrinogenio']),
    LabExamDefinition(code: 'DD', name: 'D-dímero', sector: 'Hemostasia', material: 'Plasma citratado', sireCode: '0202020500', synonyms: <String>['d dimero']),
    LabExamDefinition(code: 'GLI', name: 'Glicose', sector: 'Bioquímica', material: 'Soro ou plasma fluoretado', sireCode: '0202010473', synonyms: <String>['glicemia'], unit: 'mg/dL', requiresFasting: true, isCriticalTrackable: true),
    LabExamDefinition(code: 'HBA1C', name: 'Hemoglobina glicada', sector: 'Bioquímica', material: 'Sangue total EDTA', sireCode: '0202010503', synonyms: <String>['A1C', 'HbA1c'], unit: '%'),
    LabExamDefinition(code: 'URE', name: 'Ureia', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010694', synonyms: <String>['ureia']),
    LabExamDefinition(code: 'CRE', name: 'Creatinina', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010317', synonyms: <String>['creatinina'], isCriticalTrackable: true),
    LabExamDefinition(code: 'COL', name: 'Colesterol total', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010295', synonyms: <String>['colesterol']),
    LabExamDefinition(code: 'HDL', name: 'Colesterol HDL', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010279', synonyms: <String>['HDL']),
    LabExamDefinition(code: 'LDL', name: 'Colesterol LDL', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010287', synonyms: <String>['LDL']),
    LabExamDefinition(code: 'TRI', name: 'Triglicerídeos', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010678', synonyms: <String>['triglicerides']),
    LabExamDefinition(code: 'TGO', name: 'AST/TGO', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010643', synonyms: <String>['AST']),
    LabExamDefinition(code: 'TGP', name: 'ALT/TGP', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010651', synonyms: <String>['ALT']),
    LabExamDefinition(code: 'GGT', name: 'Gama GT', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010465', synonyms: <String>['GGT']),
    LabExamDefinition(code: 'FA', name: 'Fosfatase alcalina', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010422', synonyms: <String>['FAL']),
    LabExamDefinition(code: 'BT', name: 'Bilirrubina total e frações', sector: 'Bioquímica', material: 'Soro', sireCode: '0202010201', synonyms: <String>['bilirrubina'], isCriticalTrackable: true),
    LabExamDefinition(code: 'NA', name: 'Sódio', sector: 'Eletrólitos', material: 'Soro', sireCode: '0202010635', synonyms: <String>['sodio'], isCriticalTrackable: true),
    LabExamDefinition(code: 'K', name: 'Potássio', sector: 'Eletrólitos', material: 'Soro', sireCode: '0202010600', synonyms: <String>['potassio'], isCriticalTrackable: true),
    LabExamDefinition(code: 'CL', name: 'Cloro', sector: 'Eletrólitos', material: 'Soro', sireCode: '0202010260', synonyms: <String>['cloro']),
    LabExamDefinition(code: 'GASO', name: 'Gasometria arterial', sector: 'Gasometria', material: 'Sangue arterial heparinizado', sireCode: '0202010457', synonyms: <String>['gasometria'], isCriticalTrackable: true),
    LabExamDefinition(code: 'EAS', name: 'Urina tipo I / EAS', sector: 'Uroanálise', material: 'Urina', sireCode: '0202050017', synonyms: <String>['urina tipo 1']),
    LabExamDefinition(code: 'UROC', name: 'Urocultura', sector: 'Microbiologia', material: 'Urina', sireCode: '0202080080', synonyms: <String>['urocultura']),
    LabExamDefinition(code: 'TSH', name: 'Hormônio tireoestimulante', sector: 'Hormônios', material: 'Soro', sireCode: '0202060250', synonyms: <String>['TSH']),
    LabExamDefinition(code: 'T4L', name: 'Tiroxina livre', sector: 'Hormônios', material: 'Soro', sireCode: '0202060373', synonyms: <String>['T4 livre', 'FT4']),
    LabExamDefinition(code: 'T3', name: 'Triiodotironina', sector: 'Hormônios', material: 'Soro', sireCode: '0202060390', synonyms: <String>['T3']),
    LabExamDefinition(code: 'LH', name: 'Hormônio luteinizante', sector: 'Hormônios', material: 'Soro', sireCode: '0202060218', synonyms: <String>['LH']),
    LabExamDefinition(code: 'FSH', name: 'Hormônio folículo estimulante', sector: 'Hormônios', material: 'Soro', sireCode: '0202060200', synonyms: <String>['FSH']),
    LabExamDefinition(code: 'PRL', name: 'Prolactina', sector: 'Hormônios', material: 'Soro', sireCode: '0202060293', synonyms: <String>['prolactina']),
    LabExamDefinition(code: 'BHCG', name: 'Beta HCG', sector: 'Imunoquímica', material: 'Soro', sireCode: '0202060210', synonyms: <String>['gravidez', 'beta']),
    LabExamDefinition(code: 'VITD', name: '25 Hidroxi Vitamina D', sector: 'Hormônios', material: 'Soro', sireCode: '0202060560', synonyms: <String>['vitamina D']),
    LabExamDefinition(code: 'PCR', name: 'Proteína C reativa', sector: 'Imunologia', material: 'Soro', sireCode: '0202030203', synonyms: <String>['CRP']),
    LabExamDefinition(code: 'FR', name: 'Fator reumatoide', sector: 'Imunologia', material: 'Soro', sireCode: '0202030076', synonyms: <String>['FR']),
    LabExamDefinition(code: 'FAN', name: 'Fator antinuclear', sector: 'Imunologia', material: 'Soro', sireCode: '0202030598', synonyms: <String>['ANA']),
    LabExamDefinition(code: 'HIV', name: 'HIV 1/2', sector: 'Sorologia', material: 'Soro', sireCode: '0202031021', synonyms: <String>['HIV']),
    LabExamDefinition(code: 'HBSAG', name: 'HBsAg', sector: 'Sorologia', material: 'Soro', sireCode: '0202030971', synonyms: <String>['hepatite B']),
    LabExamDefinition(code: 'HCV', name: 'Anti-HCV', sector: 'Sorologia', material: 'Soro', sireCode: '0202031005', synonyms: <String>['hepatite C']),
    LabExamDefinition(code: 'VDRL', name: 'VDRL', sector: 'Sorologia', material: 'Soro', sireCode: '0202031110', synonyms: <String>['sifilis']),
    LabExamDefinition(code: 'DENGUE', name: 'Dengue NS1/IgM/IgG', sector: 'Sorologia', material: 'Soro', sireCode: '0202031200', synonyms: <String>['dengue']),
    LabExamDefinition(code: 'COVID', name: 'SARS-CoV-2', sector: 'Biologia Molecular', material: 'Swab nasofaríngeo', sireCode: '0202031251', synonyms: <String>['covid']),
    LabExamDefinition(code: 'PSA', name: 'PSA total', sector: 'Marcadores tumorais', material: 'Soro', sireCode: '0202030238', synonyms: <String>['PSA']),
    LabExamDefinition(code: 'CEA', name: 'Antígeno carcinoembrionário', sector: 'Marcadores tumorais', material: 'Soro', sireCode: '0202030270', synonyms: <String>['CEA']),
    LabExamDefinition(code: 'CA125', name: 'CA 125', sector: 'Marcadores tumorais', material: 'Soro', sireCode: '0202030246', synonyms: <String>['CA125']),
    LabExamDefinition(code: 'HCULT', name: 'Hemocultura', sector: 'Microbiologia', material: 'Sangue', sireCode: '0202080064', synonyms: <String>['hemocultura']),
    LabExamDefinition(code: 'COPROC', name: 'Coprocultura', sector: 'Microbiologia', material: 'Fezes', sireCode: '0202080030', synonyms: <String>['coprocultura']),
    LabExamDefinition(code: 'PARA', name: 'Parasitológico de fezes', sector: 'Parasitologia', material: 'Fezes', sireCode: '0202040011', synonyms: <String>['EPF']),
    LabExamDefinition(code: 'GRAM', name: 'Bacterioscopia Gram', sector: 'Microbiologia', material: 'Diversos', sireCode: '0202080013', synonyms: <String>['gram']),
    LabExamDefinition(code: 'BAAR', name: 'Pesquisa de BAAR', sector: 'Microbiologia', material: 'Escarro ou amostra clínica', sireCode: '0202080110', synonyms: <String>['tuberculose']),
    LabExamDefinition(code: 'TIPO', name: 'Tipagem sanguínea ABO/Rh', sector: 'Imuno-hematologia', material: 'Sangue total EDTA', sireCode: '0202120022', synonyms: <String>['ABO', 'RH']),
    LabExamDefinition(code: 'TROP', name: 'Troponina', sector: 'Urgência', material: 'Soro ou plasma', sireCode: '0202010783', synonyms: <String>['troponina'], isCriticalTrackable: true),
    LabExamDefinition(code: 'PCT', name: 'Procalcitonina', sector: 'Urgência', material: 'Soro', sireCode: '0202031308', synonyms: <String>['procalcitonina'], isCriticalTrackable: true),
  ];

  final Map<String, LabExamDefinition> _byCode = <String, LabExamDefinition>{
    for (final LabExamDefinition exam in _seed) exam.code.toUpperCase(): exam,
  };

  List<LabExamDefinition> get all => List<LabExamDefinition>.unmodifiable(_seed);

  LabExamDefinition? findByCode(String code) {
    return _byCode[code.trim().toUpperCase()];
  }

  List<LabExamDefinition> identifyByCodes(Iterable<String> codes) {
    final List<LabExamDefinition> result = <LabExamDefinition>[];
    final Set<String> used = <String>{};

    for (final String rawCode in codes) {
      final LabExamDefinition? exam = findByCode(rawCode);
      if (exam != null && used.add(exam.code)) {
        result.add(exam);
      }
    }

    return result;
  }

  List<LabExamDefinition> search(String query) {
    final String normalized = _normalize(query);
    if (normalized.isEmpty) {
      return all;
    }

    return _seed.where((LabExamDefinition exam) {
      final String text = _normalize(
        '${exam.code} ${exam.name} ${exam.sector} ${exam.material} '
        '${exam.sireCode} ${exam.synonyms.join(' ')}',
      );
      return text.contains(normalized);
    }).toList(growable: false);
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
