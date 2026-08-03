import '../models/lab_exam_definition.dart';
import 'lab_exam_catalog_service.dart';

class BarcodeExamIdentificationService {
  BarcodeExamIdentificationService({
    LabExamCatalogService? catalog,
  }) : _catalog = catalog ?? LabExamCatalogService.instance;

  final LabExamCatalogService _catalog;

  Future<BarcodeExamIdentification> identify(String rawBarcode) async {
    final String raw = rawBarcode.trim();
    final String normalized = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final List<String> examCodes = await _extractExamCodes(normalized);
    final List<LabExamDefinition> exams =
        await _catalog.identifyByCodes(examCodes);

    return BarcodeExamIdentification(
      rawBarcode: raw,
      sampleCode:
          _extractByPrefix(normalized, <String>['AMO', 'SAMPLE', 'ETQ']) ??
              _numeric(normalized, 0),
      patientCode: _extractByPrefix(normalized, <String>['PAC', 'PAT']) ??
          _numeric(normalized, 1),
      orderCode: _extractByPrefix(normalized, <String>['PED', 'ORD', 'GUIA']) ??
          _numeric(normalized, 2),
      tubeNumber: _inferTube(normalized, exams),
      examCodes: examCodes,
      detectedExams: exams,
      labelType: _detectLabelType(normalized),
      confidence: _confidence(raw, exams),
    );
  }

  String _detectLabelType(String value) {
    if (value.contains('SIRE')) return 'SIRE';
    if (value.contains('ASTM') || value.contains('HL7')) return 'Equipamento';
    if (value.contains('GUIA') || value.contains('PED')) return 'Pedido/Guia';
    if (RegExp(r'^\d{10,}$').hasMatch(value)) return 'Etiqueta numérica';
    return 'Etiqueta KRISTAL';
  }

  Future<List<String>> _extractExamCodes(String value) async {
    final Set<String> codes = <String>{};

    for (final RegExpMatch match in RegExp(
      r'(?:EX|EXAME|MNE|COD)=?([A-Z0-9,+\-/;|_]+)',
    ).allMatches(value)) {
      final String chunk = match.group(1) ?? '';
      codes.addAll(chunk.split(RegExp(r'[,+\-/;|_]+')));
    }

    for (final String token in value.split(RegExp(r'[^A-Z0-9]+'))) {
      if (await _catalog.findByCode(token) != null) {
        codes.add(token);
      }
    }

    return codes
        .map((String item) => item.trim().toUpperCase())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String? _extractByPrefix(String value, List<String> prefixes) {
    for (final String prefix in prefixes) {
      final RegExpMatch? match =
          RegExp('$prefix[:=\\-]?([A-Z0-9]{2,24})').firstMatch(value);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String _numeric(String value, int index) {
    final List<String> chunks = RegExp(r'\d{3,}')
        .allMatches(value)
        .map((RegExpMatch match) => match.group(0) ?? '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);

    if (chunks.length > index) return chunks[index];
    return '';
  }

  String _inferTube(String value, List<LabExamDefinition> exams) {
    if (value.contains('EDTA')) return 'EDTA';
    if (value.contains('CITRATO')) return 'CITRATO';
    if (value.contains('URINA')) return 'URINA';
    if (value.contains('SORO')) return 'SORO';

    if (exams
        .any((LabExamDefinition exam) => exam.sector.contains('Hematologia'))) {
      return 'EDTA';
    }
    if (exams
        .any((LabExamDefinition exam) => exam.sector.contains('Hemostasia'))) {
      return 'CITRATO';
    }
    if (exams
        .any((LabExamDefinition exam) => exam.material.contains('Urina'))) {
      return 'URINA';
    }

    return exams.isEmpty ? '' : 'SORO';
  }

  double _confidence(String raw, List<LabExamDefinition> exams) {
    double value = 0.25;
    if (raw.isNotEmpty) value += 0.25;
    if (exams.isNotEmpty) value += 0.40;
    return value.clamp(0.0, 1.0);
  }
}
