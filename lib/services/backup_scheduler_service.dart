import 'dart:async';

import 'backup_service.dart';

class BackupSchedulerService {
  BackupSchedulerService._();

  static final BackupSchedulerService instance = BackupSchedulerService._();

  Timer? _timer;
  bool _enabled = false;
  Duration _interval = const Duration(hours: 24);

  bool get enabled => _enabled;
  Duration get interval => _interval;

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

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
