import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/core/detection_engine.dart';
import 'package:badeli/core/personality.dart';

void main() {
  group('TunisianPersonality', () {
    for (final mode in PersonalityMode.values) {
      test('${mode.name} provides varied Baddel messages', () {
        final first = TunisianPersonality.getMessage(mode: mode, indexSeed: 0);
        final second = TunisianPersonality.getMessage(mode: mode, indexSeed: 1);

        expect(first, contains('Baddel!'));
        expect(second, contains('Baddel!'));
        expect(first, isNot(equals(second)));
      });
    }

    test('friendly mode reacts to the suggested language', () {
      final english = TunisianPersonality.getMessage(
        mode: PersonalityMode.tunisianFunny,
        suggestedLanguage: SuggestedLanguage.english,
        indexSeed: 0,
      );
      final arabic = TunisianPersonality.getMessage(
        mode: PersonalityMode.tunisianFunny,
        suggestedLanguage: SuggestedLanguage.arabic,
        indexSeed: 0,
      );

      expect(english, isNot(equals(arabic)));
    });

    test('uses a long typing message for long mistakes', () {
      final message = TunisianPersonality.getMessage(
        typedLength: 45,
        indexSeed: 0,
      );

      expect(message, contains('README'));
    });

    test('escalates repeated mistakes', () {
      expect(
        TunisianPersonality.getMessage(streak: 2, indexSeed: 0),
        contains('عاودناها'),
      );
      expect(
        TunisianPersonality.getMessage(streak: 3, indexSeed: 0),
        contains('حكينا في الموضوع هذا'),
      );
      expect(
        TunisianPersonality.getMessage(streak: 4, indexSeed: 0),
        contains('أنا نستقيل'),
      );
    });
  });
}
