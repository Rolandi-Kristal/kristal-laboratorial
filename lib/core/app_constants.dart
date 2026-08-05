import 'dart:io';

import 'package:path/path.dart' as p;

class AppConstants {
  AppConstants._();

  static const String appName = 'KRISTAL LABORATORIAL';
  static const String systemSubtitle = 'SISTEMA ADAPTATIVO AVANÇADO';
  static const String appSubtitle = systemSubtitle;
  static const String appFullTitle = '$appName - $systemSubtitle';
  static const String institutionName = 'HOSPITAL MILITAR DE RESENDE';
  static const String version = '1.0.0+1';

  static const String developerCredit =
      'Desenvolvedor: 3° Sgt Rolandi - H Mil Resende';

  static const String defaultSuperUserLogin = 'Kristal';
  static final String defaultSuperUserPassword = _loadSuperUserPassword();
  static const String masterLogin = defaultSuperUserLogin;
  static final String masterPassword = defaultSuperUserPassword;

  static const String logoPath = 'assets/images/kristal_login_logo.png';
  static const String hmrLogoPath = 'assets/images/hmr_brasao.png';
  static const String hmrLoginLogoPath = 'assets/images/hmr_brasao_login.png';
  static const String hmrMenuLogoPath = 'assets/images/hmr_brasao_menu.png';
  static const String hmrIconPath = 'assets/icons/hmr_brasao.ico';

  static const String localDataDirectoryName = 'kristal_laboratorial';
  static const String databaseFileName = 'kristal_laboratorial.db';
  static const String databaseName = databaseFileName;
  static const String backupExtension = '.kristalbackup';

  static const String masterKeyFile = 'kristal_master.key';
  static const String cryptoPrefix = 'KRISTAL_AES_GCM_V1:';

  static const String rootDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial';
  static const String dataDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\data';
  static const String driversDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\drivers';
  static const String backupDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\backups';
  static const String reportsDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\relatorios';
  static const String exportsDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\exports';
  static const String logsDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\logs';

  static const String bancoLocalPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\data\kristal_laboratorial.db';
  static const String backupLocalPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\backups';

  static const String servidorLocalHost = '10.4.169.64';
  static const String servidorLocalPorta = '8787';
  static const String portalPacienteUrl = 'http://10.4.169.64:8787';

  static const String kristalIntegrationsDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\integracoes';
  static const String kristalSireDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\integracoes\kristal_sire';
  static const String kristalSireCoreDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\integracoes\kristal_sire\nucleo';

  static const String kristalSireShortcutPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\integracoes\kristal_sire\KRISTAL_SIRE.lnk';
  static const String kristalSireExternalShortcutPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\integracoes\kristal_sire\KRISTAL_SIRE_EXTERNOS.lnk';

  static const String kristalSireCoreExecutablePath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\integracoes\kristal_sire\nucleo\KRISTAL_SIRE_CORE.exe';
  static const String kristalSireExternalCoreExecutablePath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\integracoes\kristal_sire\nucleo\KRISTAL_SIRE_EXTERNOS_CORE.exe';

  static const String kristalSireExportDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\exports\sire';

  static const String sireDirectoryPath = kristalSireDirectoryPath;
  static const String hyperTerminalDirectoryPath =
      r'D:\KRISTAL LABORATORIAL SISTEMA\kristal_laboratorial\integracoes\hyper_terminal';
  static const String sireExecutablePath = kristalSireShortcutPath;
  static const String sireExternalExecutablePath =
      kristalSireExternalShortcutPath;

  static const List<String> protectedClinicalTables = <String>[
    'pacientes',
    'pedidos',
    'amostras',
    'resultados',
    'laudos',
    'historico_exames_pacientes',
    'anexos',
    'auditoria',
    'etiquetas',
    'faturamento',
    'integracoes',
    'equipamentos',
    'worklists',
  ];

  static const List<String> protectedTables = protectedClinicalTables;

  static String appDataDirectoryPath() {
    final String appData = Platform.environment['APPDATA'] ?? rootDirectoryPath;
    return p.join(appData, localDataDirectoryName);
  }

  static String databasePath() {
    return p.join(appDataDirectoryPath(), databaseFileName);
  }

  static String serverConfigPath() {
    return p.join(appDataDirectoryPath(), 'server_config.json');
  }

  static String masterKeyPath() {
    return p.join(appDataDirectoryPath(), masterKeyFile);
  }

  static String superUserPasswordConfigPath() {
    return p.join(rootDirectoryPath, 'config', 'superusuario.env');
  }

  static List<String> superUserPasswordConfigPaths() {
    final String executableDir = p.dirname(Platform.resolvedExecutable);
    final String packageRoot = p.dirname(executableDir);
    return <String>[
      p.join(packageRoot, 'config', 'superusuario.env'),
      p.join(packageRoot, 'portal_web', '.env'),
      superUserPasswordConfigPath(),
      p.join(rootDirectoryPath, 'portal_web', '.env'),
    ];
  }

  static String _loadSuperUserPassword() {
    final String? envPassword =
        Platform.environment['KRISTAL_SUPERUSER_PASSWORD'];
    if (envPassword != null && envPassword.isNotEmpty) {
      return envPassword;
    }

    for (final String configPath in superUserPasswordConfigPaths()) {
      final File configFile = File(configPath);
      if (!configFile.existsSync()) {
        continue;
      }
      final String? loaded =
          _readEnvValue(configFile, 'KRISTAL_SUPERUSER_PASSWORD');
      if (loaded != null && loaded.isNotEmpty) {
        return loaded;
      }
    }
    return '';
  }

  static String? _readEnvValue(File file, String expectedKey) {
    for (final String line in file.readAsLinesSync()) {
      final String clean = line.trim();
      if (clean.isEmpty || clean.startsWith('#') || !clean.contains('=')) {
        continue;
      }
      final int separator = clean.indexOf('=');
      final String key = clean.substring(0, separator).trim();
      final String value = clean.substring(separator + 1).trim();
      if (key == expectedKey) {
        return value;
      }
    }
    return null;
  }
}
