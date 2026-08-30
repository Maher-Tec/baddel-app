import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/core/keyboard_layout.dart';

void main() {
  group('KeyboardLayout', () {
    test('converts US keys to Arabic characters', () {
      expect(
        KeyboardLayout.convert('qwerty', LayoutDirection.usToArabic),
        '\u0636\u0635\u062b\u0642\u0641\u063a',
      );
    });

    test('handles the b key as a multi-character Arabic sequence', () {
      expect(
        KeyboardLayout.convert('b', LayoutDirection.usToArabic),
        '\u0644\u0627',
      );
      expect(
        KeyboardLayout.convert('\u0644\u0627', LayoutDirection.arabicToUs),
        'b',
      );
    });

    test('prefers the multi-character reverse mapping', () {
      expect(
        KeyboardLayout.convert(
          '\u0644\u0627\u0645',
          LayoutDirection.arabicToUs,
        ),
        'bl',
      );
    });

    test('passes through punctuation, digits, spaces, and mixed scripts', () {
      expect(
        KeyboardLayout.convert('q 123! سلام', LayoutDirection.usToArabic),
        '\u0636 123! \u0633\u0644\u0627\u0645',
      );
      expect(
        KeyboardLayout.convert('\u0636 123! hello', LayoutDirection.arabicToUs),
        'q 123! hello',
      );
    });

    test('returns an empty string unchanged', () {
      expect(KeyboardLayout.convert('', LayoutDirection.usToArabic), isEmpty);
    });
  });
}
