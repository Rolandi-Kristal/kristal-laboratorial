class LabExamDefinition {
  const LabExamDefinition({
    required this.code,
    required this.name,
    required this.sector,
    required this.material,
    required this.sireCode,
    required this.synonyms,
    this.unit = '',
    this.reference = '',
    this.requiresFasting = false,
    this.isCriticalTrackable = false,
  });

  final String code;
  final String name;
  final String sector;
  final String material;
  final String sireCode;
  final List<String> synonyms;
  final String unit;
  final String reference;
  final bool requiresFasting;
  final bool isCriticalTrackable;
}

class BarcodeExamIdentification {
  const BarcodeExamIdentification({
    required this.rawBarcode,
    required this.sampleCode,
    required this.patientCode,
    required this.orderCode,
    required this.tubeNumber,
    required this.examCodes,
    required this.detectedExams,
    required this.labelType,
    required this.confidence,
  });

  final String rawBarcode;
  final String sampleCode;
  final String patientCode;
  final String orderCode;
  final String tubeNumber;
  final List<String> examCodes;
  final List<LabExamDefinition> detectedExams;
  final String labelType;
  final double confidence;

  bool get hasExamDetected => detectedExams.isNotEmpty;
}
