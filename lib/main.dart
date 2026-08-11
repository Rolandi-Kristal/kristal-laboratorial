import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/login_screen.dart';
import 'services/app_startup_service.dart';
import 'services/log_service.dart';
import 'theme/kristal_lab_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    LogService.instance.error(
      'FLUTTER_ERROR',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };

  try {
    await _configureWindowsWindow();
  } on PlatformException catch (error, stackTrace) {
    await LogService.instance.error(
      'WINDOW_MANAGER_ERROR',
      error,
      stackTrace,
    );
  } on MissingPluginException catch (error, stackTrace) {
    await LogService.instance.error(
      'WINDOW_MANAGER_ERROR',
      error,
      stackTrace,
    );
  }

  await AppStartupService.instance.start();

  runApp(const KristalLaboratorialApp());
}

Future<void> _configureWindowsWindow() async {
  await windowManager.ensureInitialized();

  const WindowOptions windowOptions = WindowOptions(
    size: Size(1366, 768),
    minimumSize: Size(1100, 720),
    center: true,
    title: 'KRISTAL LABORATORIAL',
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('KRISTAL LABORATORIAL');
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });
}

class KristalLaboratorialApp extends StatelessWidget {
  const KristalLaboratorialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KRISTAL LABORATORIAL',
      debugShowCheckedModeBanner: false,
      theme: KristalLabTheme.dark,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const <Locale>[
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginScreen(),
    );
  }
}
