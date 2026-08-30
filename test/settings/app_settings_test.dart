import 'package:badeli/core/personality.dart';
import 'package:badeli/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('uses privacy-conscious application defaults', () {
      final settings = AppSettings.inMemory();

      expect(settings.isDetectionEnabled('notepad.exe'), isTrue);
      expect(settings.isDetectionEnabled('winword.exe'), isTrue);
      expect(settings.isDetectionEnabled('code.exe'), isFalse);
      expect(settings.isDetectionEnabled('windowsterminal.exe'), isFalse);
    });

    test('always excludes sensitive applications', () {
      final settings = AppSettings.inMemory(
        detectionEnabledApps: {'bitwarden.exe', 'mstsc.exe'},
      );

      expect(settings.isDetectionEnabled('bitwarden.exe'), isFalse);
      expect(settings.isDetectionEnabled('mstsc.exe'), isFalse);
    });

    test('updates an application preference', () async {
      final settings = AppSettings.inMemory();

      await settings.setAppDetectionEnabled('code.exe', true);
      expect(settings.isDetectionEnabled('CODE.EXE'), isTrue);

      await settings.setAppDetectionEnabled('code.exe', false);
      expect(settings.isDetectionEnabled('code.exe'), isFalse);
    });

    test('global pause overrides application preferences', () async {
      final settings = AppSettings.inMemory();

      await settings.setDetectionPaused(true);
      expect(settings.isDetectionEnabled('notepad.exe'), isFalse);
    });

    test('defaults to Weld El Houma personality and allows switching modes', () async {
      final settings = AppSettings.inMemory();

      expect(settings.personalityMode, PersonalityMode.weldElHouma);

      await settings.setPersonalityMode(PersonalityMode.devTanbir);
      expect(settings.personalityMode, PersonalityMode.devTanbir);
    });
  });
}
