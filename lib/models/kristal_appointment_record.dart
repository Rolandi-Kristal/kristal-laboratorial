class KristalAppointmentRecord {
  const KristalAppointmentRecord({
    required this.id,
    required this.type,
    required this.patientName,
    required this.patientDocument,
    required this.phone,
    required this.examDescription,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    required this.priority,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.activeRecent,
    required this.archived,
    this.confirmedAppointmentId,
    this.archivedAt,
    this.archiveReason,
  });

  final String id;
  final String type;
  final String patientName;
  final String patientDocument;
  final String phone;
  final String examDescription;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String status;
  final String priority;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool activeRecent;
  final bool archived;
  final String? confirmedAppointmentId;
  final DateTime? archivedAt;
  final String? archiveReason;

  KristalAppointmentRecord copyWith({
    String? id,
    String? type,
    String? patientName,
    String? patientDocument,
    String? phone,
    String? examDescription,
    DateTime? appointmentDate,
    String? appointmentTime,
    String? status,
    String? priority,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? activeRecent,
    bool? archived,
    String? confirmedAppointmentId,
    DateTime? archivedAt,
    String? archiveReason,
  }) {
    return KristalAppointmentRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      patientName: patientName ?? this.patientName,
      patientDocument: patientDocument ?? this.patientDocument,
      phone: phone ?? this.phone,
      examDescription: examDescription ?? this.examDescription,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeRecent: activeRecent ?? this.activeRecent,
      archived: archived ?? this.archived,
      confirmedAppointmentId:
          confirmedAppointmentId ?? this.confirmedAppointmentId,
      archivedAt: archivedAt ?? this.archivedAt,
      archiveReason: archiveReason ?? this.archiveReason,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type,
      'patientName': patientName,
      'patientDocument': patientDocument,
      'phone': phone,
      'examDescription': examDescription,
      'appointmentDate': appointmentDate.toIso8601String(),
      'appointmentTime': appointmentTime,
      'status': status,
      'priority': priority,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'activeRecent': activeRecent ? '1' : '0',
      'archived': archived ? '1' : '0',
      'confirmedAppointmentId': confirmedAppointmentId,
      'archivedAt': archivedAt?.toIso8601String(),
      'archiveReason': archiveReason,
      'physicallyDeleted': '0',
      'deleteBlocked': '1',
    };
  }

  factory KristalAppointmentRecord.fromJson(Map<String, Object?> json) {
    return KristalAppointmentRecord(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'agendamento',
      patientName: json['patientName']?.toString() ?? '',
      patientDocument: json['patientDocument']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      examDescription: json['examDescription']?.toString() ?? '',
      appointmentDate:
          DateTime.tryParse(json['appointmentDate']?.toString() ?? '') ??
              DateTime.now(),
      appointmentTime: json['appointmentTime']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ativo',
      priority: json['priority']?.toString() ?? 'normal',
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      activeRecent: _asBool(json['activeRecent'], defaultValue: true),
      archived: _asBool(json['archived'], defaultValue: false),
      confirmedAppointmentId: json['confirmedAppointmentId']?.toString(),
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
        normalized == 'nao' ||
        normalized == 'não') {
      return false;
    }

    return defaultValue;
  }
}
