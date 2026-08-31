import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/personality.dart';

class BaddelTargetApp {
  const BaddelTargetApp({
    required this.processName,
    required this.label,
    required this.category,
    required this.detectionEnabledByDefault,
    this.isCustom = false,
  });

  final String processName;
  final String label;
  final String category;
  final bool detectionEnabledByDefault;
  final bool isCustom;

  Map<String, dynamic> toJson() => {
        'processName': processName,
        'label': label,
        'category': category,
        'detectionEnabledByDefault': detectionEnabledByDefault,
        'isCustom': isCustom,
      };

  factory BaddelTargetApp.fromJson(Map<String, dynamic> json) => BaddelTargetApp(
        processName: json['processName'] as String,
        label: json['label'] as String,
        category: json['category'] as String? ?? 'Custom App',
        detectionEnabledByDefault: json['detectionEnabledByDefault'] as bool? ?? true,
        isCustom: json['isCustom'] as bool? ?? true,
      );
}

class AppSettings extends ChangeNotifier {
  AppSettings._({
    required SharedPreferences? preferences,
    required bool onboardingComplete,
    required bool detectionPaused,
    required Set<String> detectionEnabledApps,
    required List<BaddelTargetApp> customTargetApps,
    required PersonalityMode personalityMode,
    required bool developerModeEnabled,
  })  : _preferences = preferences,
        _onboardingComplete = onboardingComplete,
        _detectionPaused = detectionPaused,
        _detectionEnabledApps = detectionEnabledApps,
        _customTargetApps = customTargetApps,
        _personalityMode = personalityMode,
        _developerModeEnabled = developerModeEnabled;

  static const defaultTargetApps = <BaddelTargetApp>[
    BaddelTargetApp(
      processName: 'notepad.exe',
      label: 'Notepad',
      category: 'Plain text',
      detectionEnabledByDefault: true,
    ),
    BaddelTargetApp(
      processName: 'chrome.exe',
      label: 'Google Chrome',
      category: 'Chromium Browser',
      detectionEnabledByDefault: true,
    ),
    BaddelTargetApp(
      processName: 'code.exe',
      label: 'VS Code',
      category: 'Developer IDE',
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
      category: 'Rich Document',
      detectionEnabledByDefault: true,
    ),
    BaddelTargetApp(
      processName: 'wordpad.exe',
      label: 'WordPad',
      category: 'Rich Text',
      detectionEnabledByDefault: true,
    ),
  ];

  static List<BaddelTargetApp> get targetApps => defaultTargetApps;

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
  static const _customAppsKey = 'custom_target_apps_v1';
  static const _personalityModeKey = 'personality_mode';
  static const _developerModeKey = 'developer_mode_enabled';

  final SharedPreferences? _preferences;
  bool _onboardingComplete;
  bool _detectionPaused;
  Set<String> _detectionEnabledApps;
  List<BaddelTargetApp> _customTargetApps;
  PersonalityMode _personalityMode;
  bool _developerModeEnabled;

  bool get onboardingComplete => _onboardingComplete;
  bool get detectionPaused => _detectionPaused;
  PersonalityMode get personalityMode => _personalityMode;
  bool get developerModeEnabled => _developerModeEnabled;
  Set<String> get detectionEnabledApps => Set.unmodifiable(_detectionEnabledApps);

  List<BaddelTargetApp> get allTargetApps => [...defaultTargetApps, ..._customTargetApps];

  static Set<String> get defaultEnabledApps => defaultTargetApps
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

    final rawCustomApps = preferences.getStringList(_customAppsKey) ?? [];
    final customApps = <BaddelTargetApp>[];
    for (final jsonStr in rawCustomApps) {
      try {
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        customApps.add(BaddelTargetApp.fromJson(decoded));
      } catch (_) {}
    }

    return AppSettings._(
      preferences: preferences,
      onboardingComplete: preferences.getBool(_onboardingKey) ?? false,
      detectionPaused: preferences.getBool(_detectionPausedKey) ?? false,
      detectionEnabledApps: preferences.getStringList(_enabledAppsKey)?.toSet() ?? defaultEnabledApps,
      customTargetApps: customApps,
      personalityMode: personalityMode,
      developerModeEnabled: preferences.getBool(_developerModeKey) ?? false,
    );
  }

  factory AppSettings.inMemory({
    bool onboardingComplete = true,
    bool detectionPaused = false,
    Set<String>? detectionEnabledApps,
    List<BaddelTargetApp>? customTargetApps,
    PersonalityMode personalityMode = PersonalityMode.weldElHouma,
    bool developerModeEnabled = false,
  }) =>
      AppSettings._(
        preferences: null,
        onboardingComplete: onboardingComplete,
        detectionPaused: detectionPaused,
        detectionEnabledApps: detectionEnabledApps ?? defaultEnabledApps,
        customTargetApps: customTargetApps ?? [],
        personalityMode: personalityMode,
        developerModeEnabled: developerModeEnabled,
      );

  bool isTargetApp(String processName) {
    final normalized = processName.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    final normalizedBase = normalized.replaceAll('.exe', '');

    return allTargetApps.any((app) {
      final appProc = app.processName.toLowerCase();
      final appBase = appProc.replaceAll('.exe', '');
      return appProc == normalized ||
          (appBase.isNotEmpty && normalized.contains(appBase)) ||
          (normalizedBase.isNotEmpty && appProc.contains(normalizedBase));
    });
  }

  bool isDetectionEnabled(String processName) {
    final normalized = processName.toLowerCase().trim();
    if (_detectionPaused || sensitiveProcesses.contains(normalized)) {
      return false;
    }
    final normalizedBase = normalized.replaceAll('.exe', '');

    return _detectionEnabledApps.any((enabledApp) {
      final enabledBase = enabledApp.replaceAll('.exe', '');
      return enabledApp == normalized ||
          (enabledBase.isNotEmpty && normalized.contains(enabledBase)) ||
          (normalizedBase.isNotEmpty && enabledApp.contains(normalizedBase));
    });
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

  Future<void> setDeveloperModeEnabled(bool enabled) async {
    _developerModeEnabled = enabled;
    await _preferences?.setBool(_developerModeKey, enabled);
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

  Future<void> addCustomApp({
    required String processName,
    required String label,
    String category = 'Custom Application',
  }) async {
    var normalized = processName.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (!normalized.endsWith('.exe')) {
      normalized = '$normalized.exe';
    }

    if (allTargetApps.any((app) => app.processName == normalized)) {
      await setAppDetectionEnabled(normalized, true);
      return;
    }

    final newApp = BaddelTargetApp(
      processName: normalized,
      label: label.trim().isEmpty ? normalized.replaceAll('.exe', '') : label.trim(),
      category: category,
      detectionEnabledByDefault: true,
      isCustom: true,
    );

    _customTargetApps.add(newApp);
    _detectionEnabledApps.add(normalized);

    await _saveCustomApps();
    await _preferences?.setStringList(
      _enabledAppsKey,
      _detectionEnabledApps.toList()..sort(),
    );
    notifyListeners();
  }

  Future<void> removeCustomApp(String processName) async {
    final normalized = processName.toLowerCase();
    _customTargetApps.removeWhere((app) => app.processName == normalized);
    _detectionEnabledApps.remove(normalized);

    await _saveCustomApps();
    await _preferences?.setStringList(
      _enabledAppsKey,
      _detectionEnabledApps.toList()..sort(),
    );
    notifyListeners();
  }

  Future<void> _saveCustomApps() async {
    final jsonList = _customTargetApps.map((app) => json.encode(app.toJson())).toList();
    await _preferences?.setStringList(_customAppsKey, jsonList);
  }

  Future<void> setPersonalityMode(PersonalityMode mode) async {
    _personalityMode = mode;
    await _preferences?.setString(_personalityModeKey, mode.name);
    notifyListeners();
  }
}
