import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'settings/app_settings.dart';
import 'screens/dashboard_page.dart';

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
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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

class PrivacyOnboardingPage extends StatelessWidget {
  const PrivacyOnboardingPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),

                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                                blurRadius: 14,

                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/logo/logo.png',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Baddel works locally',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                            ),

                            const Text(
                              'Your keyboard\'s little mistake detector.',
                              style: TextStyle(
                                color: Color(0xFF0D9488),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const _PrivacyPromise(
                      icon: Icons.cloud_off_rounded,
                      title: 'Zero Cloud Transmission',
                      text: 'Nothing you type is ever uploaded to any server or cloud API.',
                    ),
                    const _PrivacyPromise(

                      icon: Icons.memory_rounded,
                      title: 'Volatile RAM Only',
                      text: 'Keystrokes are held in temporary memory for pattern matching only.',
                    ),
                    const _PrivacyPromise(
                      icon: Icons.pause_circle_filled_rounded,

                      title: 'Instant Control',
                      text: 'Detection can be paused anytime with a single click or tray toggle.',
                    ),
                    const _PrivacyPromise(
                      icon: Icons.toggle_on_rounded,
                      title: 'Granular Exclusions',
                      text: 'Apps like password managers and terminals start excluded by default.',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 22, color: Color(0xFF0F766E)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Popup warnings start disabled in IDEs & terminals. Manual Ctrl+Alt+B shortcut is always ready.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF334155),

                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),

                        ),
                        onPressed: settings.completeOnboarding,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'Continue to Baddel',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),

                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyPromise extends StatelessWidget {
  const _PrivacyPromise({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  text,

                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

