import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/alarm_controller.dart';
import 'core/theme/app_theme.dart';
import 'models/alarm_state_model.dart';
import 'screens/alarm_ringing_screen.dart';
import 'screens/alarm_setup_screen.dart';
import 'screens/good_morning_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fija orientación vertical y barra de estado en Modo Oscuro puro
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AntizombiTheme.bgObsidian,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final alarmController = AlarmController();
  await alarmController.initialize();

  runApp(
    ChangeNotifierProvider<AlarmController>.value(
      value: alarmController,
      child: const AlarmaEsp32AntizombiApp(),
    ),
  );
}

class AlarmaEsp32AntizombiApp extends StatelessWidget {
  const AlarmaEsp32AntizombiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarma ESP32 Antizombi',
      debugShowCheckedModeBanner: false,
      theme: AntizombiTheme.darkTheme,
      darkTheme: AntizombiTheme.darkTheme,
      themeMode: ThemeMode.dark, // Exclusivo Modo Oscuro
      home: const _AlarmFlowRouter(),
    );
  }
}

/// Enrutador reactivo basado en el estado de [AlarmController].
/// Transiciona automáticamente entre:
/// 1. Configuración / Reposo (`AlarmSetupScreen`)
/// 2. Alarma Activa Bloqueada (`AlarmRingingScreen`)
/// 3. Éxito de Buenos Días (`GoodMorningScreen`)
class _AlarmFlowRouter extends StatelessWidget {
  const _AlarmFlowRouter();

  @override
  Widget build(BuildContext context) {
    final phase = context.select<AlarmController, AlarmPhase>((c) => c.phase);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (phase) {
        AlarmPhase.idle || AlarmPhase.armed => const AlarmSetupScreen(
            key: ValueKey('setup_screen'),
          ),
        AlarmPhase.ringing => const AlarmRingingScreen(
            key: ValueKey('ringing_screen'),
          ),
        AlarmPhase.goodMorning => const GoodMorningScreen(
            key: ValueKey('good_morning_screen'),
          ),
      },
    );
  }
}
