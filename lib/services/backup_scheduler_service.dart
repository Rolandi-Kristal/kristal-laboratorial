import 'dart:async';

import 'backup_service.dart';

class BackupSchedulerService {
  BackupSchedulerService._();

  static final BackupSchedulerService instance = BackupSchedulerService._();

  Timer? _timer;
  bool _enabled = false;
  Duration _interval = const Duration(hours: 24);
  String _dailyTime = '23:00';

  bool get enabled => _enabled;
  Duration get interval => _interval;
  String get dailyTime => _dailyTime;

  void configure({
    required bool enabled,
    Duration interval = const Duration(hours: 24),
  }) {
    _enabled = enabled;
    _interval = interval;
    _timer?.cancel();
    _timer = null;

    if (_enabled) {
      _timer = Timer.periodic(_interval, (_) async {
        await BackupService.instance.criarBackupManual();
      });
    }
  }

  void configureDaily({
    required bool enabled,
    String horario = '23:00',
  }) {
    final ({int hour, int minute}) parsed = parseAllowedTime(horario);
    _enabled = enabled;
    _dailyTime =
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    _interval = const Duration(hours: 24);
    _timer?.cancel();
    _timer = null;
    if (_enabled) _scheduleNextDaily();
  }

  static ({int hour, int minute}) parseAllowedTime(String value) {
    final RegExpMatch? match =
        RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value.trim());
    if (match == null) {
      throw const FormatException('Horário inválido. Use HH:mm.');
    }
    final int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    if (hour >= 4 && hour < 18) {
      throw const FormatException(
        'O backup deve ser configurado entre 18:00 e 03:59.',
      );
    }
    return (hour: hour, minute: minute);
  }

  void _scheduleNextDaily() {
    final ({int hour, int minute}) parsed = parseAllowedTime(_dailyTime);
    final DateTime now = DateTime.now();
    DateTime next = DateTime(
      now.year,
      now.month,
      now.day,
      parsed.hour,
      parsed.minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    _timer = Timer(next.difference(now), () async {
      try {
        await BackupService.instance.criarBackupManual();
      } finally {
        if (_enabled) _scheduleNextDaily();
      }
    });
  }

  void dispose() {
    _enabled = false;
    _timer?.cancel();
    _timer = null;
  }
}
