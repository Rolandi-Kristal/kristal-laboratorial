import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_constants.dart';
import '../models/kristal_appointment_record.dart';

class KristalAppointmentStoreService {
  KristalAppointmentStoreService._();

  static final KristalAppointmentStoreService instance =
      KristalAppointmentStoreService._();

  Future<List<KristalAppointmentRecord>> loadAll(String type) async {
    final File file = await _fileForType(type);

    if (!await file.exists()) {
      await file.writeAsString('[]', encoding: utf8);
      return <KristalAppointmentRecord>[];
    }

    final String content = await file.readAsString(encoding: utf8);
    final Object? decoded = jsonDecode(content);

    if (decoded is! List) {
      await file.writeAsString('[]', encoding: utf8);
      return <KristalAppointmentRecord>[];
    }

    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => KristalAppointmentRecord.fromJson(
            item.map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, Object?>(key.toString(), value),
            ),
          ),
        )
        .where((KristalAppointmentRecord record) => record.id.isNotEmpty)
        .toList(growable: true);
  }

  Future<List<KristalAppointmentRecord>> loadByDate({
    required String type,
    required DateTime date,
  }) async {
    final DateTime selected = DateTime(date.year, date.month, date.day);
    final List<KristalAppointmentRecord> records = await loadAll(type);

    return records.where((KristalAppointmentRecord record) {
      final DateTime recordDate = DateTime(
        record.appointmentDate.year,
        record.appointmentDate.month,
        record.appointmentDate.day,
      );

      return recordDate == selected;
    }).toList(growable: false);
  }

  Future<KristalAppointmentRecord> create({
    required String type,
    required String patientName,
    required String patientDocument,
    required String phone,
    required String examDescription,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String priority,
    required String notes,
    String status = 'ativo',
  }) async {
    final List<KristalAppointmentRecord> records = await loadAll(type);
    final DateTime now = DateTime.now();

    final KristalAppointmentRecord record = KristalAppointmentRecord(
      id: now.microsecondsSinceEpoch.toString(),
      type: type,
      patientName: patientName,
      patientDocument: patientDocument,
      phone: phone,
      examDescription: examDescription,
      appointmentDate: DateTime(
        appointmentDate.year,
        appointmentDate.month,
        appointmentDate.day,
      ),
      appointmentTime: appointmentTime,
      status: status,
      priority: priority,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      activeRecent: true,
      archived: false,
    );

    records.insert(0, record);
    await _save(type, records);
    return record;
  }

  Future<KristalAppointmentRecord> confirmPreAppointment(
    String preAppointmentId,
  ) async {
    final List<KristalAppointmentRecord> preAppointments =
        await loadAll('pre_agendamento');

    final KristalAppointmentRecord preAppointment =
        preAppointments.firstWhere(
      (KristalAppointmentRecord record) => record.id == preAppointmentId,
      orElse: () => throw const FileSystemException(
        'Pré-agendamento não encontrado.',
      ),
    );

    final KristalAppointmentRecord appointment = await create(
      type: 'agendamento',
      patientName: preAppointment.patientName,
      patientDocument: preAppointment.patientDocument,
      phone: preAppointment.phone,
      examDescription: preAppointment.examDescription,
      appointmentDate: preAppointment.appointmentDate,
      appointmentTime: preAppointment.appointmentTime,
      priority: preAppointment.priority,
      notes: preAppointment.notes,
      status: 'confirmado',
    );

    final DateTime now = DateTime.now();

    final List<KristalAppointmentRecord> updated =
        preAppointments.map((KristalAppointmentRecord record) {
      if (record.id == preAppointmentId) {
        return record.copyWith(
          status: 'confirmado',
          activeRecent: false,
          archived: true,
          confirmedAppointmentId: appointment.id,
          archivedAt: now,
          archiveReason:
              'Pré-agendamento confirmado e preservado permanentemente.',
          updatedAt: now,
        );
      }

      return record;
    }).toList(growable: true);

    await _save('pre_agendamento', updated);
    return appointment;
  }

  Future<void> archive({
    required String type,
    required String id,
    required String reason,
  }) async {
    final List<KristalAppointmentRecord> records = await loadAll(type);
    final DateTime now = DateTime.now();

    final List<KristalAppointmentRecord> updated =
        records.map((KristalAppointmentRecord record) {
      if (record.id == id) {
        return record.copyWith(
          activeRecent: false,
          archived: true,
          status: 'arquivado',
          archivedAt: now,
          archiveReason: reason,
          updatedAt: now,
        );
      }

      return record;
    }).toList(growable: true);

    await _save(type, updated);
  }

  Future<File> exportJson(String type) async {
    final List<KristalAppointmentRecord> records = await loadAll(type);
    final Directory directory = Directory(
      p.join(AppConstants.exportsDirectoryPath, 'agenda'),
    );
    await directory.create(recursive: true);

    final File file = File(
      p.join(directory.path, '${type}_${DateTime.now().millisecondsSinceEpoch}.json'),
    );

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        records
            .map((KristalAppointmentRecord record) => record.toJson())
            .toList(),
      ),
      encoding: utf8,
    );

    return file;
  }

  Future<Map<DateTime, int>> countByDay({
    required String type,
    required DateTime month,
  }) async {
    final List<KristalAppointmentRecord> records = await loadAll(type);
    final Map<DateTime, int> result = <DateTime, int>{};

    for (final KristalAppointmentRecord record in records) {
      if (record.appointmentDate.year == month.year &&
          record.appointmentDate.month == month.month &&
          record.activeRecent &&
          !record.archived) {
        final DateTime key = DateTime(
          record.appointmentDate.year,
          record.appointmentDate.month,
          record.appointmentDate.day,
        );
        result[key] = (result[key] ?? 0) + 1;
      }
    }

    return result;
  }

  Future<void> _save(
    String type,
    List<KristalAppointmentRecord> records,
  ) async {
    final File file = await _fileForType(type);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        records.map((KristalAppointmentRecord record) => record.toJson()).toList(),
      ),
      encoding: utf8,
    );
  }

  Future<File> _fileForType(String type) async {
    final Directory directory = Directory(
      p.join(AppConstants.dataDirectoryPath, 'agenda'),
    );
    await directory.create(recursive: true);
    return File(p.join(directory.path, '$type.json'));
  }
}
