import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/personality.dart';

class BaddelTargetApp {
  const BaddelTargetApp({
    required this.processName,
    required this.label,
    required this.category,
    required this.detectionEnabledByDefault,
  });

  final String processName;
  final String label;
  final String category;
  final bool detectionEnabledByDefault;
}

class AppSettings extends ChangeNotifier {
  AppSettings._({
    required SharedPreferences? preferences,
    required bool onboardingComplete,
    required bool detectionPaused,
    required Set<String> detectionEnabledApps,
    required PersonalityMode personalityMode,
  }) : _preferences = preferences,
       _onboardingComplete = onboardingComplete,
       _detectionPaused = detectionPaused,
       _detectionEnabledApps = detectionEnabledApps,
       _personalityMode = personalityMode;

  static const targetApps = <BaddelTargetApp>[
    BaddelTargetApp(
      processName: 'notepad.exe',
      label: 'Notepad',
      category: 'Plain text',
      detectionEnabledByDefault: true,
    ),
    BaddelTargetApp(
      processName: 'chrome.exe',
      label: 'Google Chrome',
      category: 'Chromium',
      detectionEnabledByDefault: true,
    ),
    BaddelTargetApp(
      processName: 'code.exe',
      label: 'VS Code',
      category: 'IDE · Electron',
      detectionEnabledByDefault: false,
    ),
    BaddelTargetApp(
      processName: 'windowsterminal.exe',
      label: 'Windows Terminal',
      category: 'Terminal',
      detectionEnabledByDefault: false,
    ),
    BaddelTargetApp(
      processName: 'winword.exe',
      label: 'Microsoft Word',
      category: 'Rich document',
      detectionEnabledByDefault: true,
    ),
    BaddelTargetApp(
      processName: 'wordpad.exe',
      label: 'WordPad',
      category: 'Rich text',
      detectionEnabledByDefault: true,
    ),
  ];

  static const sensitiveProcesses = <String>{
    'mstsc.exe',
    '1password.exe',
    'bitwarden.exe',
    'keepass.exe',
    'keepassxc.exe',
    'lastpass.exe',
  };

  static const _onboardingKey = 'onboarding_complete';
  static const _detectionPausedKey = 'detection_paused';
  static const _enabledAppsKey = 'detection_enabled_apps';
  static const _personalityModeKey = 'personality_mode';

  final SharedPreferences? _preferences;
  bool _onboardingComplete;
  bool _detectionPaused;
  Set<String> _detectionEnabledApps;
  PersonalityMode _personalityMode;

  bool get onboardingComplete => _onboardingComplete;
  bool get detectionPaused => _detectionPaused;
  PersonalityMode get personalityMode => _personalityMode;
  Set<String> get detectionEnabledApps =>
      Set.unmodifiable(_detectionEnabledApps);

  static Set<String> get defaultEnabledApps => targetApps
      .where((app) => app.detectionEnabledByDefault)
      .map((app) => app.processName)
      .toSet();

  static Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_personalityModeKey);
    final personalityMode = PersonalityMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => PersonalityMode.weldElHouma,
    );

    return AppSettings._(
      preferences: preferences,
      onboardingComplete: preferences.getBool(_onboardingKey) ?? false,
      detectionPaused: preferences.getBool(_detectionPausedKey) ?? false,
      detectionEnabledApps:
          preferences.getStringList(_enabledAppsKey)?.toSet() ??
          defaultEnabledApps,
      personalityMode: personalityMode,
    );
  }

  factory AppSettings.inMemory({
    bool onboardingComplete = true,
    bool detectionPaused = false,
    Set<String>? detectionEnabledApps,
    PersonalityMode personalityMode = PersonalityMode.weldElHouma,
  }) => AppSettings._(
    preferences: null,
    onboardingComplete: onboardingComplete,
    detectionPaused: detectionPaused,
    detectionEnabledApps: detectionEnabledApps ?? defaultEnabledApps,
    personalityMode: personalityMode,
  );

  bool isTargetApp(String processName) =>
      targetApps.any((app) => app.processName == processName.toLowerCase());

  bool isDetectionEnabled(String processName) {
    final normalized = processName.toLowerCase();
    return !_detectionPaused &&
        !sensitiveProcesses.contains(normalized) &&
        _detectionEnabledApps.contains(normalized);
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    await _preferences?.setBool(_onboardingKey, true);
    notifyListeners();
  }

  Future<void> setDetectionPaused(bool paused) async {
    _detectionPaused = paused;
    await _preferences?.setBool(_detectionPausedKey, paused);
    notifyListeners();
  }

  Future<void> setAppDetectionEnabled(String processName, bool enabled) async {
    final normalized = processName.toLowerCase();
    if (enabled) {
      _detectionEnabledApps.add(normalized);
    } else {
      _detectionEnabledApps.remove(normalized);
    }
    await _preferences?.setStringList(
      _enabledAppsKey,
      _detectionEnabledApps.toList()..sort(),
    );
    notifyListeners();
  }

  Future<void> setPersonalityMode(PersonalityMode mode) async {
    _personalityMode = mode;
    await _preferences?.setString(_personalityModeKey, mode.name);
    notifyListeners();
  }
}
