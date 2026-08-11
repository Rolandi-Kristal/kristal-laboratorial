class KristalOperationalRecord {
  const KristalOperationalRecord({
    required this.id,
    required this.module,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    required this.activeRecent,
    required this.archived,
    this.archivedAt,
    this.archiveReason,
  });

  final String id;
  final String module;
  final Map<String, String> data;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool activeRecent;
  final bool archived;
  final DateTime? archivedAt;
  final String? archiveReason;

  KristalOperationalRecord copyWith({
    String? id,
    String? module,
    Map<String, String>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? activeRecent,
    bool? archived,
    DateTime? archivedAt,
    String? archiveReason,
  }) {
    return KristalOperationalRecord(
      id: id ?? this.id,
      module: module ?? this.module,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeRecent: activeRecent ?? this.activeRecent,
      archived: archived ?? this.archived,
      archivedAt: archivedAt ?? this.archivedAt,
      archiveReason: archiveReason ?? this.archiveReason,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'module': module,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'activeRecent': activeRecent ? '1' : '0',
      'archived': archived ? '1' : '0',
      'archivedAt': archivedAt?.toIso8601String(),
      'archiveReason': archiveReason,
      'physicallyDeleted': '0',
      'deleteBlocked': '1',
    };
  }

  factory KristalOperationalRecord.fromJson(Map<String, Object?> json) {
    final Object? dataValue = json['data'];
    final Map<String, String> parsedData = <String, String>{};

    if (dataValue is Map) {
      for (final MapEntry<dynamic, dynamic> entry in dataValue.entries) {
        parsedData[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }

    return KristalOperationalRecord(
      id: json['id']?.toString() ?? '',
      module: json['module']?.toString() ?? '',
      data: parsedData,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      activeRecent: _asBool(json['activeRecent'], defaultValue: true),
      archived: _asBool(json['archived'], defaultValue: false),
      archivedAt: DateTime.tryParse(json['archivedAt']?.toString() ?? ''),
      archiveReason: json['archiveReason']?.toString(),
    );
  }

  static bool _asBool(Object? value, {required bool defaultValue}) {
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == '1' || normalized == 'true' || normalized == 'sim') {
      return true;
    }
    if (normalized == '0' ||
        normalized == 'false' ||
        normalized == 'não' ||
        normalized == 'nao') {
      return false;
    }
    return defaultValue;
  }
}
