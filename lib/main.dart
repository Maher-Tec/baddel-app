import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/dashboard_page.dart';
import 'screens/onboarding_page.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(BaddelApp(settings: settings));
}

class BaddelApp extends StatelessWidget {
  BaddelApp({super.key, AppSettings? settings, this.enableDesktopShell = true})
    : settings = settings ?? AppSettings.inMemory();

  final AppSettings settings;
  final bool enableDesktopShell;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        title: 'Baddel!',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D9488),
            primary: const Color(0xFF0D9488),
            secondary: const Color(0xFF0284C7),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          useMaterial3: true,
          fontFamily: 'Segoe UI',
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: Colors.white,
          ),
        ),
        home: settings.onboardingComplete
            ? HookTestPage(
                settings: settings,
                enableDesktopShell: enableDesktopShell,
              )
            : PrivacyOnboardingPage(settings: settings),
      ),
    );
  }
}
