import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/core/detection_engine.dart';
import 'package:badeli/core/personality.dart';

void main() {
  group('TunisianPersonality', () {
    test('provides Weld El Houma authentic street humor messages', () {
      final msg1 = TunisianPersonality.getMessage(
        mode: PersonalityMode.weldElHouma,
        indexSeed: 0,
      );
      final msg2 = TunisianPersonality.getMessage(
        mode: PersonalityMode.weldElHouma,
        indexSeed: 1,
      );

      expect(msg1, isNotEmpty);
      expect(msg2, isNotEmpty);
      expect(msg1, isNot(equals(msg2)));
      expect(msg1, contains('Baddel!'));
    });

    test('provides Dev Tanbir coder jokes in devTanbir mode', () {
      final msg1 = TunisianPersonality.getMessage(
        mode: PersonalityMode.devTanbir,
        indexSeed: 0,
      );
      final msg2 = TunisianPersonality.getMessage(
        mode: PersonalityMode.devTanbir,
        indexSeed: 1,
      );

      expect(msg1, isNotEmpty);
      expect(msg2, isNotEmpty);
      expect(msg1, isNot(equals(msg2)));
      expect(msg1, contains('Baddel!'));
    });

    test('provides authentic funny messages for Arabic active layout (English typed)', () {
      final msg1 = TunisianPersonality.getMessage(
        mode: PersonalityMode.tunisianFunny,
        suggestedLanguage: SuggestedLanguage.english,
        indexSeed: 0,
      );
      final msg2 = TunisianPersonality.getMessage(
        mode: PersonalityMode.tunisianFunny,
        suggestedLanguage: SuggestedLanguage.english,
        indexSeed: 1,
      );

      expect(msg1, isNotEmpty);
      expect(msg2, isNotEmpty);
      expect(msg1, isNot(equals(msg2)));
      expect(msg1, contains('Baddel!'));
    });

    test('provides authentic funny messages for English active layout (Arabic typed)', () {
      final msg1 = TunisianPersonality.getMessage(
        mode: PersonalityMode.tunisianFunny,
        suggestedLanguage: SuggestedLanguage.arabic,
        indexSeed: 0,
      );
      final msg2 = TunisianPersonality.getMessage(
        mode: PersonalityMode.tunisianFunny,
        suggestedLanguage: SuggestedLanguage.arabic,
        indexSeed: 1,
      );

      expect(msg1, isNotEmpty);
      expect(msg2, isNotEmpty);
      expect(msg1, isNot(equals(msg2)));
      expect(msg1, contains('Baddel!'));
    });

    test('provides classic messages in classic mode', () {
      final msg = TunisianPersonality.getMessage(
        mode: PersonalityMode.classic,
        indexSeed: 0,
      );
      expect(msg, isNotEmpty);
      expect(msg, contains('Baddel!'));
    });

    test('roasts user when long chunk is typed in wrong layout', () {
      final msg = TunisianPersonality.getMessage(
        mode: PersonalityMode.weldElHouma,
        typedLength: 45,
        indexSeed: 0,
      );
      expect(msg, isNotEmpty);
      expect(msg, contains('Baddel!'));
      final isLongRoast = msg.contains('باراغراف') ||
          msg.contains('README') ||
          msg.contains('الكتاب') ||
          msg.contains('رواية') ||
          msg.contains('Record') ||
          msg.contains('47') ||
          msg.contains('تعبت') ||
          msg.contains('Respect') ||
          msg.contains('publish') ||
          msg.contains('Breaking news') ||
          msg.contains('الفصل');
      expect(isLongRoast, isTrue);
    });

    test('escalates patience levels on consecutive mistake streaks', () {
      final level2 = TunisianPersonality.getMessage(
        streak: 2,
        indexSeed: 0,
      );
      final level3 = TunisianPersonality.getMessage(
        streak: 3,
        indexSeed: 0,
      );
      final level4 = TunisianPersonality.getMessage(
        streak: 4,
        indexSeed: 0,
      );

      expect(level2, contains('عاودناها'));
      expect(level3, contains('حكينا في الموضوع هذا'));
      expect(level4, contains('أنا نستقيل'));
    });
  });
}
