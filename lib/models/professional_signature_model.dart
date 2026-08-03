class ProfessionalSignatureModel {
  const ProfessionalSignatureModel({
    required this.professionalName,
    required this.rankOrGrade,
    required this.specialty,
    required this.council,
    required this.councilNumber,
    required this.signatureImagePath,
    required this.updatedAt,
  });

  final String professionalName;
  final String rankOrGrade;
  final String specialty;
  final String council;
  final String councilNumber;
  final String signatureImagePath;
  final DateTime updatedAt;

  bool get hasSignatureImage => signatureImagePath.trim().isNotEmpty;

  String get fullCouncil {
    final String cleanCouncil = council.trim();
    final String cleanNumber = councilNumber.trim();

    if (cleanCouncil.isEmpty && cleanNumber.isEmpty) {
      return '';
    }

    if (cleanCouncil.isEmpty) {
      return cleanNumber;
    }

    if (cleanNumber.isEmpty) {
      return cleanCouncil;
    }

    return '$cleanCouncil: $cleanNumber';
  }

  String get professionalLine {
    final List<String> parts = <String>[
      professionalName.trim(),
      rankOrGrade.trim(),
      specialty.trim(),
      fullCouncil.trim(),
    ].where((String value) => value.isNotEmpty).toList(growable: false);

    return parts.join(' - ');
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'professionalName': professionalName,
      'rankOrGrade': rankOrGrade,
      'specialty': specialty,
      'council': council,
      'councilNumber': councilNumber,
      'signatureImagePath': signatureImagePath,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProfessionalSignatureModel.fromJson(Map<String, Object?> json) {
    return ProfessionalSignatureModel(
      professionalName: json['professionalName']?.toString() ?? '',
      rankOrGrade: json['rankOrGrade']?.toString() ?? '',
      specialty: json['specialty']?.toString() ?? '',
      council: json['council']?.toString() ?? '',
      councilNumber: json['councilNumber']?.toString() ?? '',
      signatureImagePath: json['signatureImagePath']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory ProfessionalSignatureModel.empty() {
    return ProfessionalSignatureModel(
      professionalName: '',
      rankOrGrade: '',
      specialty: '',
      council: '',
      councilNumber: '',
      signatureImagePath: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
