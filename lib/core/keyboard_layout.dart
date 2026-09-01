/// Direction of a keyboard-layout conversion.
enum LayoutDirection { usToArabic, arabicToUs }

enum KeyboardLayoutProfile { usQwerty, frenchAzerty, arabic101, arabicPhonetic }

/// Deterministic keyboard-layout conversion for Baddel V1.
///
/// This is intentionally a pure function: it has no clipboard, platform, or
/// detection concerns, which keeps it easy to test and safe to reuse later.
class KeyboardLayout {
  const KeyboardLayout._();

  static const Map<String, String> usToArabic = {
    'q': '\u0636', // ض
    'w': '\u0635', // ص
    'e': '\u062b', // ث
    'r': '\u0642', // ق
    't': '\u0641', // ف
    'y': '\u063a', // غ
    'u': '\u0639', // ع
    'i': '\u0647', // ه
    'o': '\u062e', // خ
    'p': '\u062d', // ح
    '[': '\u062c', // ج
    ']': '\u062f', // د
    'a': '\u0634', // ش
    's': '\u0633', // س
    'd': '\u064a', // ي
    'f': '\u0628', // ب
    'g': '\u0644', // ل
    'h': '\u0627', // ا
    'j': '\u062a', // ت
    'k': '\u0646', // ن
    'l': '\u0645', // م
    ';': '\u0643', // ك
    "'": '\u0637', // ط
    'z': '\u0626', // ئ
    'x': '\u0621', // ء
    'c': '\u0624', // ؤ
    'v': '\u0631', // ر
    'b': '\u0644\u0627', // لا (one key -> two characters)
    'n': '\u0649', // ى
    'm': '\u0629', // ة
    ',': '\u0648', // و
    '.': '\u0632', // ز
    '/': '\u0638', // ظ
  };

  /// The reverse map is explicit because `b` maps to two Arabic characters.
  static const Map<String, String> arabicToUs = {
    '\u0636': 'q',
    '\u0635': 'w',
    '\u062b': 'e',
    '\u0642': 'r',
    '\u0641': 't',
    '\u063a': 'y',
    '\u0639': 'u',
    '\u0647': 'i',
    '\u062e': 'o',
    '\u062d': 'p',
    '\u062c': '[',
    '\u062f': ']',
    '\u0634': 'a',
    '\u0633': 's',
    '\u064a': 'd',
    '\u0628': 'f',
    '\u0644': 'g',
    '\u0627': 'h',
    '\u062a': 'j',
    '\u0646': 'k',
    '\u0645': 'l',
    '\u0643': ';',
    '\u0637': "'",
    '\u0626': 'z',
    '\u0621': 'x',
    '\u0624': 'c',
    '\u0631': 'v',
    '\u0644\u0627': 'b',
    '\u0649': 'n',
    '\u0629': 'm',
    '\u0648': ',',
    '\u0632': '.',
    '\u0638': '/',
  };

  static String convert(String input, LayoutDirection direction) {
    return switch (direction) {
      LayoutDirection.usToArabic => _convertUsToArabic(input),
      LayoutDirection.arabicToUs => _convertArabicToUs(input),
    };
  }

  /// Converts text using the selected physical keyboard profile.
  ///
  /// AZERTY is normalized through the US physical-key representation, which
  /// lets the existing Arabic 101 map remain the single source of truth.
  static String convertForProfile(
    String input,
    LayoutDirection direction,
    KeyboardLayoutProfile profile,
  ) {
    if (profile == KeyboardLayoutProfile.usQwerty ||
        profile == KeyboardLayoutProfile.arabic101) {
      return convert(input, direction);
    }
    if (profile == KeyboardLayoutProfile.frenchAzerty) {
      return direction == LayoutDirection.usToArabic
          ? convert(_azertyToQwerty(input), direction)
          : _qwertyToAzerty(convert(input, direction));
    }
    return direction == LayoutDirection.usToArabic
        ? _phoneticToArabic(input)
        : _arabicToPhonetic(input);
  }

  static const Map<String, String> _phoneticMap = {
    'a': '\u0627', 'b': '\u0628', 't': '\u062a', 'j': '\u062c',
    '7': '\u062d', 'd': '\u062f', 'r': '\u0631', 'z': '\u0632',
    's': '\u0633', 'f': '\u0641', 'q': '\u0642', 'k': '\u0643',
    'l': '\u0644', 'm': '\u0645', 'n': '\u0646', 'h': '\u0647',
    'w': '\u0648', 'y': '\u064a', '3': '\u0639', 'g': '\u063a',
    'x': '\u0634', '9': '\u0635', 'v': '\u0636',
  };

  static String _phoneticToArabic(String input) => input
      .split('')
      .map((character) => _phoneticMap[character.toLowerCase()] ?? character)
      .join();

  static String _arabicToPhonetic(String input) {
    final reverse = {for (final entry in _phoneticMap.entries) entry.value: entry.key};
    return input.split('').map((character) => reverse[character] ?? character).join();
  }

  static const Map<String, String> _azertyToQwertyMap = {
    'a': 'q', 'z': 'w', 'q': 'a', 'w': 'z',
    'A': 'Q', 'Z': 'W', 'Q': 'A', 'W': 'Z',
  };

  static String _azertyToQwerty(String input) => input
      .split('')
      .map((character) => _azertyToQwertyMap[character] ?? character)
      .join();

  static String _qwertyToAzerty(String input) => input.split('').map((character) {
        for (final entry in _azertyToQwertyMap.entries) {
          if (entry.value == character) return entry.key;
        }
        return character;
      }).join();

  static String _convertUsToArabic(String input) {
    final output = StringBuffer();
    for (final character in input.split('')) {
      final mapped = usToArabic[character.toLowerCase()];
      output.write(mapped ?? character);
    }
    return output.toString();
  }

  static String _convertArabicToUs(String input) {
    final output = StringBuffer();
    var index = 0;
    while (index < input.length) {
      final twoCharacters = index + 2 <= input.length
          ? input.substring(index, index + 2)
          : null;
      final twoCharacterMapping = twoCharacters == null
          ? null
          : arabicToUs[twoCharacters];
      if (twoCharacterMapping != null) {
        output.write(twoCharacterMapping);
        index += 2;
        continue;
      }

      final character = input[index];
      output.write(arabicToUs[character] ?? character);
      index++;
    }
    return output.toString();
  }
}
