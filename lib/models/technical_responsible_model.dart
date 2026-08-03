class TechnicalResponsibleModel {
  const TechnicalResponsibleModel({
    required this.name,
    required this.rankOrGrade,
    required this.specialty,
    required this.council,
    required this.councilNumber,
    required this.updatedAt,
  });

  final String name;
  final String rankOrGrade;
  final String specialty;
  final String council;
  final String councilNumber;
  final DateTime updatedAt;

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

  String get printableLine {
    final List<String> parts = <String>[
      name.trim(),
      rankOrGrade.trim(),
      specialty.trim(),
      fullCouncil.trim(),
    ].where((String value) => value.isNotEmpty).toList(growable: false);

    if (parts.isEmpty) {
      return 'Responsável Técnico não cadastrado';
    }

    return 'Responsável Técnico: ${parts.join(' - ')}';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'rankOrGrade': rankOrGrade,
      'specialty': specialty,
      'council': council,
      'councilNumber': councilNumber,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TechnicalResponsibleModel.fromJson(Map<String, Object?> json) {
    return TechnicalResponsibleModel(
      name: json['name']?.toString() ?? '',
      rankOrGrade: json['rankOrGrade']?.toString() ?? '',
      specialty: json['specialty']?.toString() ?? '',
      council: json['council']?.toString() ?? '',
      councilNumber: json['councilNumber']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory TechnicalResponsibleModel.empty() {
    return TechnicalResponsibleModel(
      name: '',
      rankOrGrade: '',
      specialty: '',
      council: '',
      councilNumber: '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
