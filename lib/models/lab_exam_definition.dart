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
    this.active = true,
    this.deleted = false,
    this.updatedAt = '',
    this.updatedBy = '',
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
  final bool active;
  final bool deleted;
  final String updatedAt;
  final String updatedBy;

  LabExamDefinition copyWith({
    String? code,
    String? name,
    String? sector,
    String? material,
    String? sireCode,
    List<String>? synonyms,
    String? unit,
    String? reference,
    bool? requiresFasting,
    bool? isCriticalTrackable,
    bool? active,
    bool? deleted,
    String? updatedAt,
    String? updatedBy,
  }) {
    return LabExamDefinition(
      code: code ?? this.code,
      name: name ?? this.name,
      sector: sector ?? this.sector,
      material: material ?? this.material,
      sireCode: sireCode ?? this.sireCode,
      synonyms: synonyms ?? this.synonyms,
      unit: unit ?? this.unit,
      reference: reference ?? this.reference,
      requiresFasting: requiresFasting ?? this.requiresFasting,
      isCriticalTrackable: isCriticalTrackable ?? this.isCriticalTrackable,
      active: active ?? this.active,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'code': code,
      'name': name,
      'sector': sector,
      'material': material,
      'sireCode': sireCode,
      'synonyms': synonyms,
      'unit': unit,
      'reference': reference,
      'requiresFasting': requiresFasting,
      'isCriticalTrackable': isCriticalTrackable,
      'active': active,
      'deleted': deleted,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }

  factory LabExamDefinition.fromJson(Map<String, Object?> json) {
    final Object? rawSynonyms = json['synonyms'];
    final List<String> parsedSynonyms = rawSynonyms is List
        ? rawSynonyms
            .map((Object? value) => value.toString())
            .toList(growable: false)
        : json['synonyms']
                ?.toString()
                .split(',')
                .map((String value) => value.trim())
                .where((String value) => value.isNotEmpty)
                .toList(growable: false) ??
            const <String>[];

    return LabExamDefinition(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sector: json['sector']?.toString() ?? '',
      material: json['material']?.toString() ?? '',
      sireCode: json['sireCode']?.toString() ?? '',
      synonyms: parsedSynonyms,
      unit: json['unit']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      requiresFasting: json['requiresFasting'] == true ||
          json['requiresFasting']?.toString() == 'true',
      isCriticalTrackable: json['isCriticalTrackable'] == true ||
          json['isCriticalTrackable']?.toString() == 'true',
      active: json['active'] != false && json['active']?.toString() != 'false',
      deleted: json['deleted'] == true || json['deleted']?.toString() == 'true',
      updatedAt: json['updatedAt']?.toString() ?? '',
      updatedBy: json['updatedBy']?.toString() ?? '',
    );
  }
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
